package roomapp

import (
	"log/slog"
	"sync"
	"sync/atomic"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"
)

// Types and sentinel errors: service_input_types.go
// Room lifecycle: service_room_lifecycle.go
// Member config: service_member_config.go
// Matchmaking: service_matchmaking.go
// Battle operations: service_battle.go
// ToggleReady: service_ready.go
// Read-only queries: service_queries.go
// Directory: service_directory.go
// Sync loops + projections: service_sync_loops.go
// Validation: service_validation.go
// Helpers + phase/slot utils: service_helpers.go

type Service struct {
	registry *registry.Registry
	manifest *manifest.Loader
	query    *manifest.Query
	verifier *auth.TicketVerifier
	game     *gameclient.Client
	logger   *slog.Logger

	mu                        sync.RWMutex
	roomsByID                 map[string]*domain.RoomAggregate
	roomByMemberID            map[string]string
	roomOwnerByID             map[string]string
	emptyBattleRoomCleanupDue map[string]time.Time
	emptyBattleCleanupGrace   time.Duration
	idCounter                 atomic.Int64
	metrics                   ControlPlaneMetrics
}

var roomTransitionEngine = RoomTransitionEngine{}

func NewService(reg *registry.Registry, man *manifest.Loader, verifier *auth.TicketVerifier, game *gameclient.Client) *Service {
	return &Service{
		registry:                  reg,
		manifest:                  man,
		query:                     manifest.NewQuery(man),
		verifier:                  verifier,
		game:                      game,
		roomsByID:                 map[string]*domain.RoomAggregate{},
		roomByMemberID:            map[string]string{},
		roomOwnerByID:             map[string]string{},
		emptyBattleRoomCleanupDue: map[string]time.Time{},
		emptyBattleCleanupGrace:   30 * time.Second,
	}
}

func (s *Service) SetEmptyBattleCleanupGrace(grace time.Duration) {
	if s == nil || grace <= 0 {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.emptyBattleCleanupGrace = grace
}

func (s *Service) SetLogger(logger *slog.Logger) {
	if s == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.logger = logger
}

func (s *Service) Ready() bool {
	return s != nil &&
		s.registry != nil &&
		s.registry.Ready() &&
		s.manifest != nil &&
		s.manifest.Ready() &&
		s.verifier != nil
}

func (s *Service) GetControlPlaneMetrics() map[string]int64 {
	if s == nil {
		return map[string]int64{}
	}
	return map[string]int64{
		"manual_battle_assignment_sync_count":         s.metrics.manualBattleAssignmentSyncCount.Load(),
		"manual_battle_queue_status_call_count":       s.metrics.manualBattleQueueStatusCallCount.Load(),
		"battle_assignment_status_error_count":        s.metrics.battleAssignmentStatusErrorCount.Load(),
		"battle_assignment_revision_stale_drop_count": s.metrics.battleAssignmentRevisionStaleDropCount.Load(),
		"queue_sync_target_count":                     s.metrics.queueSyncTargetCount.Load(),
		"battle_sync_target_count":                    s.metrics.battleSyncTargetCount.Load(),
		"queue_state_manual_room_write_count":         s.metrics.queueStateManualRoomWriteCount.Load(),
	}
}

func (s *Service) SweepEmptyBattleRooms(now time.Time) int {
	if s == nil {
		return 0
	}
	type cleanupTarget struct {
		roomID       string
		assignmentID string
		battleID     string
	}
	targets := make([]cleanupTarget, 0)

	s.mu.Lock()
	for roomID, due := range s.emptyBattleRoomCleanupDue {
		if now.Before(due) {
			continue
		}
		room := s.roomsByID[roomID]
		if room == nil {
			delete(s.emptyBattleRoomCleanupDue, roomID)
			continue
		}
		if !isBattleRoomEmpty(room) || !shouldDelayEmptyBattleCleanup(room) {
			delete(s.emptyBattleRoomCleanupDue, roomID)
			continue
		}
		targets = append(targets, cleanupTarget{
			roomID:       roomID,
			assignmentID: room.BattleState.AssignmentID,
			battleID:     room.BattleState.BattleID,
		})
		s.destroyRoomLocked(roomID)
	}
	s.mu.Unlock()

	for _, target := range targets {
		if s.game == nil || target.battleID == "" {
			continue
		}
		s.executeBattleReap(battleReapRequest{
			roomID:       target.roomID,
			assignmentID: target.assignmentID,
			battleID:     target.battleID,
			reason:       "empty_battle_room_sweep",
		})
	}
	return len(targets)
}

func (s *Service) executeBattleReap(request battleReapRequest) bool {
	if s == nil || s.game == nil || request.battleID == "" {
		return false
	}
	_, err := s.game.ReapBattle(gameclient.ReapBattleInput{
		RoomID:       request.roomID,
		AssignmentID: request.assignmentID,
		BattleID:     request.battleID,
	})
	if err != nil {
		if s.logger != nil {
			s.logger.Warn(
				"battle reap failed",
				"event", "battle_reap_failed",
				"room_id", request.roomID,
				"assignment_id", request.assignmentID,
				"battle_id", request.battleID,
				"reason", request.reason,
				"error", err.Error(),
			)
		}
		return false
	}
	if s.logger != nil {
		s.logger.Info(
			"battle reaped",
			"event", "battle_reaped",
			"room_id", request.roomID,
			"assignment_id", request.assignmentID,
			"battle_id", request.battleID,
			"reason", request.reason,
		)
	}
	return true
}
