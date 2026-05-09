package roomapp

import (
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"
)

var (
	ErrInvalidTicket      = errors.New("invalid room ticket")
	ErrInvalidLoadout     = errors.New("invalid loadout")
	ErrInvalidSelection   = errors.New("invalid room selection")
	ErrRoomNotFound       = errors.New("room not found")
	ErrRoomNotJoinable    = errors.New("room not joinable")
	ErrMemberNotFound     = errors.New("member not found")
	ErrReconnectForbidden = errors.New("reconnect token mismatch")
	ErrNotRoomOwner       = errors.New("room owner required")
	ErrMatchRoomOnly      = errors.New("match room required")
	ErrMembersNotReady    = errors.New("all members must be ready")
	ErrQueueStateInvalid  = errors.New("queue state does not allow enter queue")
	ErrRoomPhaseInvalid   = errors.New("room phase does not allow operation")
	ErrMemberPhaseInvalid = errors.New("member phase does not allow operation")
	ErrPartySizeMismatch  = errors.New("MATCHMAKING_PARTY_SIZE_MISMATCH")
	ErrManualRoomOnly     = errors.New("manual room required")
	ErrInvalidRoomKind    = errors.New("invalid room kind")
)

type Loadout struct {
	CharacterID   string
	BubbleStyleID string
}

type Selection struct {
	MapID           string
	RuleSetID       string
	ModeID          string
	MatchFormatID   string
	SelectedModeIDs []string
}

type CreateRoomInput struct {
	RoomKind        string
	RoomDisplayName string
	RoomTicket      string
	AccountID       string
	ProfileID       string
	PlayerName      string
	ConnectionID    string
	Loadout         Loadout
	Selection       Selection
}

type JoinRoomInput struct {
	RoomID       string
	RoomTicket   string
	AccountID    string
	ProfileID    string
	PlayerName   string
	ConnectionID string
	Loadout      Loadout
}

type ResumeRoomInput struct {
	RoomID         string
	MemberID       string
	ReconnectToken string
	ConnectionID   string
	RoomTicket     string
}

type LeaveRoomInput struct {
	RoomID   string
	MemberID string
}

type UpdateProfileInput struct {
	RoomID     string
	MemberID   string
	PlayerName string
	TeamID     int
	Loadout    Loadout
}

type UpdateSelectionInput struct {
	RoomID          string
	MemberID        string
	Selection       Selection
	OpenSlotIndices []int
}

type UpdateMatchRoomConfigInput struct {
	RoomID          string
	MemberID        string
	MatchFormatID   string
	SelectedModeIDs []string
}

type EnterMatchQueueInput struct {
	RoomID   string
	MemberID string
}

type CancelMatchQueueInput struct {
	RoomID   string
	MemberID string
}

type StartManualRoomBattleInput struct {
	RoomID   string
	MemberID string
}

type AckBattleEntryInput struct {
	RoomID       string
	MemberID     string
	AssignmentID string
	BattleID     string
	MatchID      string
}

type ToggleReadyInput struct {
	RoomID   string
	MemberID string
}

type SnapshotProjection struct {
	RoomID               string
	RoomKind             string
	RoomDisplayName      string
	LifecycleState       string
	RoomPhase            string
	RoomPhaseReason      string
	SnapshotRevision     int64
	OwnerMemberID        string
	Selection            domain.RoomSelection
	Members              []domain.RoomMember
	MaxPlayerCount       int
	OpenSlotIndices      []int
	QueuePhase           string
	QueueTerminalReason  string
	QueueStatusText      string
	QueueErrorCode       string
	QueueUserMessage     string
	QueueEntryID         string
	BattlePhase          string
	BattleTerminalReason string
	BattleStatusText     string
	Capabilities         domain.RoomCapabilitySet
	QueueState           domain.RoomQueueState
	BattleHandoff        domain.BattleHandoff
}

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

type ControlPlaneMetrics struct {
	manualBattleAssignmentSyncCount        atomic.Int64
	manualBattleQueueStatusCallCount       atomic.Int64
	battleAssignmentStatusErrorCount       atomic.Int64
	battleAssignmentRevisionStaleDropCount atomic.Int64
	queueSyncTargetCount                   atomic.Int64
	battleSyncTargetCount                  atomic.Int64
	queueStateManualRoomWriteCount         atomic.Int64
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

func (s *Service) CreateRoom(input CreateRoomInput) (*SnapshotProjection, error) {
	if !s.Ready() {
		return nil, fmt.Errorf("room app not ready")
	}
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}
	normalizedRoomKind, err := normalizeRoomKind(input.RoomKind)
	if err != nil {
		return nil, err
	}
	input.RoomKind = normalizedRoomKind

	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	resolvedSelection, mapEntry, err := s.validateSelection(input.RoomKind, input.Selection, 1)
	if err != nil {
		return nil, err
	}

	roomID := s.nextID("room")
	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	member := domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          1,
		SlotIndex:       0,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:     resolvedLoadout.CharacterID,
			BubbleStyleID:   resolvedLoadout.BubbleStyleID,
		},
	}

	agg := &domain.RoomAggregate{
		RoomID:          roomID,
		RoomKind:        input.RoomKind,
		RoomDisplayName: input.RoomDisplayName,
		Selection: domain.RoomSelection{
			MapID:           resolvedSelection.MapID,
			RuleSetID:       resolvedSelection.RuleSetID,
			ModeID:          resolvedSelection.ModeID,
			MatchFormatID:   resolvedSelection.MatchFormatID,
			SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
		},
		Members: map[string]domain.RoomMember{
			member.MemberID: member,
		},
		Queue: domain.RoomQueueState{
			QueueType: "",
		},
		ResumeBindings: map[string]domain.ResumeBinding{
			member.MemberID: {
				MemberID:                member.MemberID,
				ReconnectToken:          reconnectToken,
				ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
			},
		},
		RoomState: domain.RoomFSMState{
			Phase:      RoomPhaseIdle,
			LastReason: RoomReasonNone,
		},
		QueueState: domain.QueueFSMProjection{
			Phase:          QueuePhaseIdle,
			TerminalReason: QueueReasonNone,
		},
		BattleState: domain.BattleHandoffFSMProjection{
			Phase:          BattlePhaseIdle,
			TerminalReason: BattleReasonNone,
		},
		MaxPlayerCount:  mapEntry.MaxPlayerCount,
		OpenSlotIndices: defaultOpenSlotIndices(mapEntry.MaxPlayerCount),
	}
	roomTransitionEngine.ApplyCreateRoom(agg, memberID)

	s.mu.Lock()
	s.roomsByID[roomID] = agg
	s.roomByMemberID[memberID] = roomID
	s.roomOwnerByID[roomID] = memberID
	s.syncDirectoryEntryLocked(agg)
	s.mu.Unlock()

	return s.snapshotProjectionLocked(agg), nil
}

func (s *Service) JoinRoom(input JoinRoomInput) (*SnapshotProjection, error) {
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	slotIndex, ok := firstAvailableSlot(room.OpenSlotIndices, room.Members)
	if !ok {
		return nil, ErrRoomNotJoinable
	}

	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	teamID := resolveJoinTeamID(room.Members)
	room.Members[memberID] = domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          teamID,
		SlotIndex:       slotIndex,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:     resolvedLoadout.CharacterID,
			BubbleStyleID:   resolvedLoadout.BubbleStyleID,
		},
	}
	room.ResumeBindings[memberID] = domain.ResumeBinding{
		MemberID:                memberID,
		ReconnectToken:          reconnectToken,
		ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
	}
	s.roomByMemberID[memberID] = room.RoomID
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func resolveJoinTeamID(members map[string]domain.RoomMember) int {
	const maxTeamID = 8
	if len(members) == 1 {
		for _, member := range members {
			for teamID := 1; teamID <= maxTeamID; teamID++ {
				if teamID != member.TeamID {
					return teamID
				}
			}
		}
		return 1
	}

	teamCounts := make(map[int]int, maxTeamID)
	for _, member := range members {
		if member.TeamID >= 1 && member.TeamID <= maxTeamID {
			teamCounts[member.TeamID]++
		}
	}
	bestTeamID := 1
	bestCount := len(members) + 1
	for teamID := 1; teamID <= maxTeamID; teamID++ {
		count, ok := teamCounts[teamID]
		if !ok {
			continue
		}
		if count < bestCount {
			bestTeamID = teamID
			bestCount = count
		}
	}
	return bestTeamID
}

func (s *Service) ResumeRoom(input ResumeRoomInput) (*SnapshotProjection, error) {
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	binding := room.ResumeBindings[input.MemberID]
	if binding.ReconnectToken != input.ReconnectToken {
		return nil, ErrReconnectForbidden
	}
	member.ConnectionID = input.ConnectionID
	member.ConnectionState = "connected"
	room.Members[input.MemberID] = member
	delete(s.emptyBattleRoomCleanupDue, input.RoomID)
	restoreMemberPhase(room, input.MemberID)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) MarkDisconnected(roomID string, memberID string) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	member.ConnectionState = "disconnected"
	member.ConnectionID = ""
	room.Members[memberID] = member
	markMemberDisconnected(room, memberID)
	s.updateEmptyBattleCleanupLocked(room, time.Now())
	s.syncDirectoryEntryLocked(room)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) LeaveRoom(input LeaveRoomInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	delete(room.Members, input.MemberID)
	delete(room.ResumeBindings, input.MemberID)
	delete(s.roomByMemberID, input.MemberID)
	ownerChanged := false
	if s.roomOwnerByID[input.RoomID] == input.MemberID {
		s.roomOwnerByID[input.RoomID] = selectNextRoomOwner(room.Members)
		ownerChanged = true
	}

	if len(room.Members) == 0 && shouldDelayEmptyBattleCleanup(room) {
		s.registry.RemoveRoomEntry(input.RoomID)
		s.scheduleEmptyBattleCleanupLocked(room, time.Now())
		return nil, nil
	}
	if len(room.Members) == 0 {
		s.destroyRoomLocked(input.RoomID)
		return nil, nil
	}
	s.updateEmptyBattleCleanupLocked(room, time.Now())
	roomTransitionEngine.ApplyMemberLeft(room, s.roomOwnerByID[input.RoomID], ownerChanged)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) updateEmptyBattleCleanupLocked(room *domain.RoomAggregate, now time.Time) {
	if room == nil {
		return
	}
	if isBattleRoomEmpty(room) && shouldDelayEmptyBattleCleanup(room) {
		s.scheduleEmptyBattleCleanupLocked(room, now)
		return
	}
	delete(s.emptyBattleRoomCleanupDue, room.RoomID)
}

func (s *Service) scheduleEmptyBattleCleanupLocked(room *domain.RoomAggregate, now time.Time) {
	if room == nil {
		return
	}
	grace := s.emptyBattleCleanupGrace
	if grace <= 0 {
		grace = 30 * time.Second
	}
	s.emptyBattleRoomCleanupDue[room.RoomID] = now.Add(grace)
}

func (s *Service) destroyRoomLocked(roomID string) {
	room := s.roomsByID[roomID]
	if room != nil {
		for memberID := range room.Members {
			delete(s.roomByMemberID, memberID)
		}
	}
	s.registry.RemoveRoomEntry(roomID)
	delete(s.roomsByID, roomID)
	delete(s.roomOwnerByID, roomID)
	delete(s.emptyBattleRoomCleanupDue, roomID)
}

func isBattleRoomEmpty(room *domain.RoomAggregate) bool {
	if room == nil {
		return false
	}
	if len(room.Members) == 0 {
		return true
	}
	for _, member := range room.Members {
		if member.ConnectionState != "disconnected" {
			return false
		}
	}
	return true
}

func shouldDelayEmptyBattleCleanup(room *domain.RoomAggregate) bool {
	if room == nil || room.BattleState.BattleID == "" {
		return false
	}
	switch room.BattleState.Phase {
	case "", BattlePhaseIdle, BattlePhaseCompleted, "failed", "cancelled":
		return false
	default:
		return true
	}
}

func (s *Service) UpdateProfile(input UpdateProfileInput) (*SnapshotProjection, error) {
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	if input.PlayerName != "" {
		member.PlayerName = input.PlayerName
	}
	if input.TeamID > 0 {
		member.TeamID = input.TeamID
	}
	member.Loadout = domain.RoomLoadout{
		CharacterID:     resolvedLoadout.CharacterID,
		BubbleStyleID:   resolvedLoadout.BubbleStyleID,
	}
	room.Members[input.MemberID] = member
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateSelection(input UpdateSelectionInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isManualRoomKind(room.RoomKind) {
		return nil, ErrManualRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	roomKind := room.RoomKind
	if roomKind == "" {
		roomKind = "private_room"
	}
	resolvedSelection, mapEntry, err := s.validateSelection(roomKind, input.Selection, len(room.Members))
	if err != nil {
		return nil, err
	}
	room.Selection = domain.RoomSelection{
		MapID:           resolvedSelection.MapID,
		RuleSetID:       resolvedSelection.RuleSetID,
		ModeID:          resolvedSelection.ModeID,
		MatchFormatID:   resolvedSelection.MatchFormatID,
		SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
	}
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	if len(input.OpenSlotIndices) > 0 {
		normalizedSlots, normalizeErr := normalizeOpenSlotIndices(input.OpenSlotIndices, mapEntry.MaxPlayerCount, room.Members)
		if normalizeErr != nil {
			return nil, normalizeErr
		}
		room.OpenSlotIndices = normalizedSlots
	} else {
		room.OpenSlotIndices = expandOpenSlotIndices(room.OpenSlotIndices, mapEntry.MaxPlayerCount, room.Members)
	}
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateMatchRoomConfig(input UpdateMatchRoomConfigInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}

	selectedModeIDs := append([]string{}, input.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(input.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}

	queueType := "casual"
	if room.RoomKind == "ranked_match_room" {
		queueType = "ranked"
	}
	mapPool, err := s.query.ResolveMapPool(input.MatchFormatID, selectedModeIDs, queueType)
	if err != nil || len(mapPool) == 0 {
		return nil, ErrInvalidSelection
	}
	mapEntry := mapPool[0]

	room.Selection.MatchFormatID = input.MatchFormatID
	room.Selection.SelectedModeIDs = selectedModeIDs
	room.Selection.MapID = mapEntry.MapID
	room.Selection.ModeID = mapEntry.ModeID
	room.Selection.RuleSetID = mapEntry.RuleSetID
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) EnterMatchQueue(input EnterMatchQueueInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	requiredPartySize := s.query.RequiredPartySize(room.Selection.MatchFormatID)
	if len(room.Members) != requiredPartySize {
		return nil, ErrPartySizeMismatch
	}
	selectedModeIDs := append([]string{}, room.Selection.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(room.Selection.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	queueType := queueTypeByRoomKind(room.RoomKind)
	roomTransitionEngine.ApplyQueueEnterRequested(room, s.roomOwnerByID[input.RoomID])
	gameInput := gameclient.EnterPartyQueueInput{
		RoomID:          room.RoomID,
		RoomKind:        room.RoomKind,
		QueueType:       queueType,
		MatchFormatID:   room.Selection.MatchFormatID,
		SelectedModeIDs: append([]string{}, room.Selection.SelectedModeIDs...),
		Members:         buildPartyMembers(room.Members),
	}
	result, err := s.game.EnterPartyQueue(gameInput)
	if err != nil {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], "ENTER_QUEUE_RPC_ERROR", err.Error())
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.Queue.QueueType = queueType
	queuePhase, terminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	statusText := resolveQueueStatusText(result.QueueStatusText, result.StatusText, result.QueueState)
	roomTransitionEngine.ApplyQueueAccepted(
		room,
		s.roomOwnerByID[input.RoomID],
		queuePhase,
		terminalReason,
		statusText,
		result.QueueEntryID,
		"",
		"",
	)
	room.Queue.QueueType = queueType
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) CancelMatchQueue(input CancelMatchQueueInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	switch room.RoomState.Phase {
	case RoomPhaseQueueActive, RoomPhaseBattleAllocating, RoomPhaseBattleEntryReady:
	default:
		return nil, ErrRoomPhaseInvalid
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	previousRoomPhase := room.RoomState.Phase
	roomTransitionEngine.ApplyQueueCancelRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CancelPartyQueue(gameclient.CancelPartyQueueInput{
		RoomID:       room.RoomID,
		RoomKind:     room.RoomKind,
		QueueType:    room.Queue.QueueType,
		QueueEntryID: room.Queue.QueueEntryID,
	})
	if err != nil {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}
	roomTransitionEngine.ApplyQueueCancelled(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}

type QueueStatusSyncResult struct {
	RoomID   string
	Snapshot *SnapshotProjection
}

func (s *Service) SyncMatchQueueStatus() []QueueStatusSyncResult {
	if s == nil || s.game == nil {
		return nil
	}

	targets := s.collectQueueSyncTargets()
	s.metrics.queueSyncTargetCount.Add(int64(len(targets)))
	if len(targets) == 0 {
		return nil
	}

	updates := make([]QueueStatusSyncResult, 0, len(targets))
	for _, target := range targets {
		result, err := s.game.GetPartyQueueStatus(gameclient.GetPartyQueueStatusInput{
			RoomID:       target.roomID,
			RoomKind:     target.roomKind,
			QueueEntryID: target.queueEntryID,
		})
		if err != nil {
			continue
		}
		snapshot, changed := s.applyQueueStatusResult(target, result)
		if changed && snapshot != nil {
			updates = append(updates, QueueStatusSyncResult{
				RoomID:   target.roomID,
				Snapshot: snapshot,
			})
		}
	}
	return updates
}

func (s *Service) StartManualRoomBattle(input StartManualRoomBattleInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isManualRoomKind(room.RoomKind) {
		return nil, ErrManualRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if !nonOwnerMembersReady(room.Members, s.roomOwnerByID[input.RoomID]) {
		return nil, ErrMembersNotReady
	}
	if !canStartManualRoom(room) {
		return nil, ErrMembersNotReady
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	roomTransitionEngine.ApplyManualBattleRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CreateManualRoomBattle(gameclient.CreateManualRoomBattleInput{
		RoomID:    room.RoomID,
		RoomKind:  room.RoomKind,
		MapID:     room.Selection.MapID,
		ModeID:    room.Selection.ModeID,
		RuleSetID: room.Selection.RuleSetID,
		Members:   buildPartyMembers(room.Members),
	})
	if err != nil {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], "MANUAL_BATTLE_ALLOCATE_RPC_ERROR", err.Error())
		s.syncDirectoryEntryLocked(room)
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		s.syncDirectoryEntryLocked(room)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	ready := result.Ready || isManualBattleAllocationReady(result.AllocationState, result.ServerHost, result.ServerPort)
	phase := BattlePhaseAllocating
	if ready {
		phase = BattlePhaseReady
	}
	roomTransitionEngine.ApplyBattleHandoffUpdated(room, s.roomOwnerByID[input.RoomID], BattleHandoffUpdate{
		AssignmentID:       result.AssignmentID,
		AssignmentRevision: result.AssignmentRevision,
		MatchID:            result.MatchID,
		BattleID:           result.BattleID,
		ServerHost:         result.ServerHost,
		ServerPort:         result.ServerPort,
		Phase:              phase,
		TerminalReason:     BattleReasonManualStart,
		Ready:              ready,
	})
	if isManualRoomKind(room.RoomKind) && room.QueueState.QueueEntryID != "" {
		s.metrics.queueStateManualRoomWriteCount.Add(1)
		panic("DEBT-011: manual room must not write QueueState")
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) AckBattleEntry(input AckBattleEntryInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	handoff := room.BattleState
	if room.RoomState.Phase == RoomPhaseInBattle && room.BattleState.Phase == BattlePhaseActive {
		if handoff.AssignmentID == "" || handoff.AssignmentID != input.AssignmentID {
			return nil, fmt.Errorf("assignment mismatch")
		}
		if handoff.BattleID != "" && input.BattleID != "" && handoff.BattleID != input.BattleID {
			return nil, fmt.Errorf("battle mismatch")
		}
		if handoff.MatchID != "" && input.MatchID != "" && handoff.MatchID != input.MatchID {
			return nil, fmt.Errorf("match mismatch")
		}
		s.syncDirectoryEntryLocked(room)
		return s.snapshotProjectionLocked(room), nil
	}
	if room.RoomState.Phase != RoomPhaseBattleEntryReady || room.BattleState.Phase != BattlePhaseReady {
		return nil, ErrRoomPhaseInvalid
	}
	if handoff.AssignmentID == "" || handoff.AssignmentID != input.AssignmentID {
		return nil, fmt.Errorf("assignment mismatch")
	}
	if handoff.BattleID != "" && input.BattleID != "" && handoff.BattleID != input.BattleID {
		return nil, fmt.Errorf("battle mismatch")
	}
	if handoff.MatchID != "" && input.MatchID != "" && handoff.MatchID != input.MatchID {
		return nil, fmt.Errorf("match mismatch")
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	result, err := s.game.CommitAssignmentReady(gameclient.CommitAssignmentReadyInput{
		RoomID:             room.RoomID,
		RoomKind:           room.RoomKind,
		AssignmentID:       input.AssignmentID,
		AccountID:          member.AccountID,
		ProfileID:          member.ProfileID,
		AssignmentRevision: handoff.AssignmentRevision,
		BattleID:           input.BattleID,
		MatchID:            input.MatchID,
	})
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	roomTransitionEngine.ApplyBattleEntryAckRequested(room, s.roomOwnerByID[input.RoomID])
	room.BattleState.StatusText = "battle_entry_acknowledged"
	roomTransitionEngine.ApplyBattleEntryAcked(room, s.roomOwnerByID[input.RoomID])
	if strings.TrimSpace(result.CommittedState) == "committed" {
		roomTransitionEngine.ApplyBattleStarted(room, s.roomOwnerByID[input.RoomID])
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) ToggleReady(input ToggleReadyInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if member.MemberPhase != MemberPhaseIdle && member.MemberPhase != MemberPhaseReady {
		return nil, ErrMemberPhaseInvalid
	}
	if !toggleMemberReady(room, input.MemberID) {
		return nil, ErrMemberPhaseInvalid
	}
	roomTransitionEngine.ApplyToggleReady(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) SnapshotProjection(roomID string) (*SnapshotProjection, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) ReconnectToken(roomID, memberID string) (string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return "", ErrRoomNotFound
	}
	binding, ok := room.ResumeBindings[memberID]
	if !ok {
		return "", ErrMemberNotFound
	}
	return binding.ReconnectToken, nil
}

func (s *Service) ResolveRoomMemberByConnection(connectionID string) (string, string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for roomID, room := range s.roomsByID {
		for memberID, member := range room.Members {
			if member.ConnectionID == connectionID {
				return roomID, memberID, nil
			}
		}
	}
	return "", "", ErrMemberNotFound
}

func (s *Service) SetDirectorySubscribed(connectionID string, subscribed bool) {
	if s == nil || s.registry == nil {
		return
	}
	s.registry.SetDirectorySubscribed(connectionID, subscribed)
}

func (s *Service) DirectorySubscriberIDs() []string {
	if s == nil || s.registry == nil {
		return nil
	}
	return s.registry.DirectorySubscriberIDs()
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

func (s *Service) DirectorySnapshot(serverHost string, serverPort int32) *roomv1.RoomDirectorySnapshot {
	result := &roomv1.RoomDirectorySnapshot{
		ServerHost: serverHost,
		ServerPort: serverPort,
	}
	if s == nil || s.registry == nil {
		return result
	}
	snapshot := s.registry.DirectorySnapshot()
	result.Revision = snapshot.Revision
	result.Entries = make([]*roomv1.RoomDirectoryEntry, 0, len(snapshot.Entries))
	for _, entry := range snapshot.Entries {
		result.Entries = append(result.Entries, &roomv1.RoomDirectoryEntry{
			RoomId:          entry.RoomID,
			RoomDisplayName: entry.RoomDisplayName,
			RoomKind:        entry.RoomKind,
			ModeId:          entry.ModeID,
			MapId:           entry.MapID,
			MemberCount:     entry.MemberCount,
			MaxPlayerCount:  entry.MaxPlayerCount,
			Joinable:        entry.Joinable,
		})
	}
	return result
}

func (s *Service) validateLoadout(loadout Loadout) (Loadout, error) {
	resolved := loadout
	if resolved.CharacterID == "" {
		resolved.CharacterID = s.manifest.Manifest().Assets.DefaultCharacterID
	}
	if !s.manifest.HasLegalCharacterID(resolved.CharacterID) {
		return Loadout{}, ErrInvalidLoadout
	}
	if resolved.BubbleStyleID == "" {
		resolved.BubbleStyleID = s.manifest.Manifest().Assets.DefaultBubbleStyleID
	}
	if !s.manifest.HasLegalBubbleStyleID(resolved.BubbleStyleID) {
		return Loadout{}, ErrInvalidLoadout
	}
	return resolved, nil
}

func (s *Service) validateSelection(roomKind string, selection Selection, memberCount int) (Selection, *manifest.MapEntry, error) {
	resolved := selection
	var mapEntry *manifest.MapEntry

	switch domain.ParseRoomKindCategory(roomKind) {
	case domain.RoomKindMatch, domain.RoomKindRanked:
		if strings.TrimSpace(resolved.MatchFormatID) == "" {
			resolved.MatchFormatID = s.query.DefaultMatchFormatID()
		}
		if len(resolved.SelectedModeIDs) == 0 && strings.TrimSpace(resolved.ModeID) == "" {
			if matchFormat := s.query.FindMatchFormat(resolved.MatchFormatID); matchFormat != nil && len(matchFormat.LegalModeIDs) > 0 {
				resolved.ModeID = matchFormat.LegalModeIDs[0]
			}
		}
		if len(resolved.SelectedModeIDs) == 0 && resolved.ModeID != "" {
			resolved.SelectedModeIDs = []string{resolved.ModeID}
		}
		if _, err := s.query.ValidateMatchRoomConfig(resolved.MatchFormatID, resolved.SelectedModeIDs); err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		queueType := "casual"
		if domain.ParseRoomKindCategory(roomKind) == domain.RoomKindRanked {
			queueType = "ranked"
		}
		mapPool, err := s.query.ResolveMapPool(resolved.MatchFormatID, resolved.SelectedModeIDs, queueType)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = &mapPool[0]
		resolved.MapID = mapEntry.MapID
		resolved.ModeID = mapEntry.ModeID
		resolved.RuleSetID = mapEntry.RuleSetID
	default:
		if resolved.MapID == "" {
			first := s.manifest.FirstMap()
			if first == nil {
				return Selection{}, nil, ErrInvalidSelection
			}
			resolved.MapID = first.MapID
		}
		mapEntry = s.manifest.FindMap(resolved.MapID)
		if mapEntry == nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		if resolved.ModeID == "" {
			resolved.ModeID = mapEntry.ModeID
		}
		if resolved.RuleSetID == "" {
			resolved.RuleSetID = mapEntry.RuleSetID
		}
		if resolved.MatchFormatID == "" && len(mapEntry.MatchFormatIDs) > 0 {
			resolved.MatchFormatID = mapEntry.MatchFormatIDs[0]
		}
		validated, err := s.query.ValidateCustomRoomSelection(resolved.MapID, resolved.ModeID, resolved.RuleSetID)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = validated
	}

	if err := s.query.ValidateTeamAndPlayerCount(mapEntry.MapID, mapEntry.RequiredTeamCount, memberCount); err != nil {
		return Selection{}, nil, ErrInvalidSelection
	}
	return resolved, mapEntry, nil
}

func (s *Service) snapshotProjectionLocked(room *domain.RoomAggregate) *SnapshotProjection {
	if room == nil {
		return nil
	}
	if isManualRoomKind(room.RoomKind) && room.QueueState.QueueEntryID != "" {
		s.metrics.queueStateManualRoomWriteCount.Add(1)
		panic("DEBT-011: manual room QueueState must remain empty")
	}
	members := make([]domain.RoomMember, 0, len(room.Members))
	for _, member := range room.Members {
		member.ReconnectToken = ""
		members = append(members, member)
	}
	capabilities := projectRoomCapabilities(room, s.roomOwnerByID[room.RoomID], s.query)
	return &SnapshotProjection{
		RoomID:               room.RoomID,
		RoomKind:             room.RoomKind,
		RoomDisplayName:      room.RoomDisplayName,
		LifecycleState:       room.LifecycleState,
		RoomPhase:            room.RoomState.Phase,
		RoomPhaseReason:      room.RoomState.LastReason,
		SnapshotRevision:     room.SnapshotRevision,
		OwnerMemberID:        s.roomOwnerByID[room.RoomID],
		Selection:            room.Selection,
		Members:              members,
		MaxPlayerCount:       room.MaxPlayerCount,
		OpenSlotIndices:      append([]int{}, room.OpenSlotIndices...),
		QueuePhase:           room.QueueState.Phase,
		QueueTerminalReason:  room.QueueState.TerminalReason,
		QueueStatusText:      room.QueueState.StatusText,
		QueueErrorCode:       room.QueueState.ErrorCode,
		QueueUserMessage:     room.QueueState.UserMessage,
		QueueEntryID:         room.QueueState.QueueEntryID,
		BattlePhase:          room.BattleState.Phase,
		BattleTerminalReason: room.BattleState.TerminalReason,
		BattleStatusText:     room.BattleState.StatusText,
		Capabilities:         capabilities,
		QueueState:           room.Queue,
		BattleHandoff:        room.BattleHandoffState,
	}
}

func (s *Service) nextID(prefix string) string {
	value := s.idCounter.Add(1)
	return fmt.Sprintf("%s-%d-%d", prefix, time.Now().UnixNano(), value)
}

func isMatchRoomKind(roomKind string) bool {
	kind := domain.ParseRoomKindCategory(roomKind)
	return kind == domain.RoomKindMatch || kind == domain.RoomKindRanked
}

func isManualRoomKind(roomKind string) bool {
	return domain.ParseRoomKindCategory(roomKind) == domain.RoomKindCustom
}

func isDirectoryVisibleRoomKind(roomKind string) bool {
	return roomKind != "" && roomKind != "private_room"
}

func queueTypeByRoomKind(roomKind string) string {
	if domain.ParseRoomKindCategory(roomKind) == domain.RoomKindRanked {
		return "ranked"
	}
	return "casual"
}

func normalizeRoomKind(roomKind string) (string, error) {
	switch strings.TrimSpace(roomKind) {
	case "private_room":
		return "private_room", nil
	case "public_room":
		return "public_room", nil
	}

	switch domain.ParseRoomKindCategory(roomKind) {
	case domain.RoomKindCustom:
		return "custom_room", nil
	case domain.RoomKindMatch:
		return "casual_match_room", nil
	case domain.RoomKindRanked:
		return "ranked_match_room", nil
	default:
		if strings.TrimSpace(roomKind) == "" {
			return "custom_room", nil
		}
		return "", ErrInvalidRoomKind
	}
}

func canEnterQueueFromState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case "", QueuePhaseIdle:
		return true
	default:
		return false
	}
}

func canCancelQueueFromState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case QueuePhaseQueued, QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle, QueuePhaseEntryReady:
		return true
	default:
		return false
	}
}

func shouldSyncQueueState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case QueuePhaseQueued, QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle, QueuePhaseEntryReady:
		return true
	default:
		return false
	}
}

type queueSyncTarget struct {
	roomID       string
	roomKind     string
	queueEntryID string
}

func (s *Service) collectQueueSyncTargets() []queueSyncTarget {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targets := make([]queueSyncTarget, 0)
	for _, room := range s.roomsByID {
		if room == nil {
			continue
		}
		if room.QueueState.QueueEntryID == "" {
			continue
		}
		if !isMatchRoomKind(room.RoomKind) {
			continue
		}
		if !shouldSyncQueueState(room.QueueState.Phase) {
			continue
		}
		targets = append(targets, queueSyncTarget{
			roomID:       room.RoomID,
			roomKind:     room.RoomKind,
			queueEntryID: room.QueueState.QueueEntryID,
		})
	}
	return targets
}

type battleSyncTarget struct {
	roomID             string
	roomKind           string
	assignmentID       string
	assignmentRevision int
}

type battleReapRequest struct {
	roomID       string
	assignmentID string
	battleID     string
	reason       string
}

func (s *Service) collectBattleSyncTargets() []battleSyncTarget {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targets := make([]battleSyncTarget, 0)
	for _, room := range s.roomsByID {
		if room == nil {
			continue
		}
		if room.BattleState.AssignmentID == "" {
			continue
		}
		if room.BattleState.Phase == "" || room.BattleState.Phase == "completed" || room.BattleState.Phase == "cancelled" || room.BattleState.Phase == "failed" {
			continue
		}
		targets = append(targets, battleSyncTarget{
			roomID:             room.RoomID,
			roomKind:           room.RoomKind,
			assignmentID:       room.BattleState.AssignmentID,
			assignmentRevision: room.BattleState.AssignmentRevision,
		})
	}
	return targets
}

func (s *Service) SyncBattleAssignmentStatus() []QueueStatusSyncResult {
	if s == nil || s.game == nil {
		return nil
	}

	targets := s.collectBattleSyncTargets()
	s.metrics.battleSyncTargetCount.Add(int64(len(targets)))
	if len(targets) == 0 {
		return nil
	}

	updates := make([]QueueStatusSyncResult, 0, len(targets))
	reapRequests := make([]battleReapRequest, 0, len(targets))
	for _, target := range targets {
		result, err := s.game.GetBattleAssignmentStatus(gameclient.GetBattleAssignmentStatusInput{
			RoomID:        target.roomID,
			RoomKind:      target.roomKind,
			AssignmentID:  target.assignmentID,
			KnownRevision: int64(target.assignmentRevision),
		})
		if err != nil {
			s.metrics.battleAssignmentStatusErrorCount.Add(1)
			continue
		}
		if !result.OK {
			if isBattleAssignmentGone(result) {
				if room := s.applyBattleGoneProjection(target); room != nil {
					if isManualRoomKind(target.roomKind) {
						s.metrics.manualBattleAssignmentSyncCount.Add(1)
					}
					updates = append(updates, QueueStatusSyncResult{
						RoomID:   target.roomID,
						Snapshot: room,
					})
				}
				continue
			}
			s.metrics.battleAssignmentStatusErrorCount.Add(1)
			continue
		}
		room, reapRequest := s.applyBattleAssignmentProjection(target, result)
		if room != nil {
			if isManualRoomKind(target.roomKind) {
				s.metrics.manualBattleAssignmentSyncCount.Add(1)
			}
			updates = append(updates, QueueStatusSyncResult{
				RoomID:   target.roomID,
				Snapshot: room,
			})
		}
		if reapRequest != nil {
			reapRequests = append(reapRequests, *reapRequest)
		}
	}
	for _, request := range reapRequests {
		s.executeBattleReap(request)
	}
	return updates
}

func (s *Service) applyBattleGoneProjection(target battleSyncTarget) *SnapshotProjection {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil
	}
	if room.BattleState.AssignmentID != target.assignmentID {
		return nil
	}

	roomTransitionEngine.ApplyReturnCompleted(room, s.roomOwnerByID[target.roomID])
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room)
}

func (s *Service) applyBattleAssignmentProjection(target battleSyncTarget, result gameclient.GetBattleAssignmentStatusResult) (*SnapshotProjection, *battleReapRequest) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil, nil
	}
	if room.BattleState.AssignmentID != target.assignmentID {
		return nil, nil
	}
	if result.AssignmentRevision > 0 && room.BattleState.AssignmentRevision > int(result.AssignmentRevision) {
		s.metrics.battleAssignmentRevisionStaleDropCount.Add(1)
		return nil, nil
	}
	if !shouldAcceptBattleAssignmentProjection(room.RoomState.Phase, result.BattlePhase, result.Finalized) {
		s.logBattleProjectionIgnoredLocked(room, result)
		return nil, nil
	}

	room.BattleState.Phase = result.BattlePhase
	room.BattleState.TerminalReason = result.TerminalReason
	room.BattleState.Ready = result.BattleEntryReady
	if result.AssignmentID != "" {
		room.BattleState.AssignmentID = result.AssignmentID
	}
	if result.AssignmentRevision > 0 {
		room.BattleState.AssignmentRevision = int(result.AssignmentRevision)
	}
	if result.MatchID != "" {
		room.BattleState.MatchID = result.MatchID
	}
	if result.BattleID != "" {
		room.BattleState.BattleID = result.BattleID
	}
	if result.ServerHost != "" {
		room.BattleState.ServerHost = result.ServerHost
	}
	if result.ServerPort > 0 {
		room.BattleState.ServerPort = int(result.ServerPort)
	}
	transitionFinalized := false
	var reapRequest *battleReapRequest = nil
	switch result.BattlePhase {
	case "allocating":
		room.RoomState.Phase = RoomPhaseBattleAllocating
	case "ready":
		room.RoomState.Phase = RoomPhaseBattleEntryReady
	case "entering":
		room.RoomState.Phase = RoomPhaseBattleEntering
	case "active":
		room.RoomState.Phase = RoomPhaseInBattle
		promoteMembersToBattle(room)
	case "returning":
		roomTransitionEngine.ApplyBattleReturning(room, s.roomOwnerByID[target.roomID], result.TerminalReason)
		transitionFinalized = true
	case "completed", "failed", "cancelled":
		roomTransitionEngine.ApplyReturnCompleted(room, s.roomOwnerByID[target.roomID])
		transitionFinalized = true
	default:
		if room.RoomState.Phase == RoomPhaseBattleAllocating || room.RoomState.Phase == RoomPhaseBattleEntryReady || room.RoomState.Phase == RoomPhaseBattleEntering {
			lockMembersForQueue(room)
		}
	}

	if !transitionFinalized {
		finalizeRoomTransition(room, s.roomOwnerByID[target.roomID])
	} else if room.BattleState.BattleID != "" {
		reapRequest = &battleReapRequest{
			roomID:       room.RoomID,
			assignmentID: room.BattleState.AssignmentID,
			battleID:     room.BattleState.BattleID,
			reason:       "terminal_phase:" + result.BattlePhase,
		}
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), reapRequest
}

func shouldAcceptBattleAssignmentProjection(currentRoomPhase, resultBattlePhase string, finalized bool) bool {
	if finalized || isTerminalBattlePhase(resultBattlePhase) {
		return true
	}
	switch currentRoomPhase {
	case RoomPhaseBattleEntering:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseEntering)
	case RoomPhaseInBattle:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseActive)
	case RoomPhaseReturningToRoom:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseReturning)
	default:
		return true
	}
}

func isTerminalBattlePhase(phase string) bool {
	switch phase {
	case BattlePhaseCompleted, "failed", "cancelled":
		return true
	default:
		return false
	}
}

func battlePhaseOrder(phase string) int {
	switch phase {
	case BattlePhaseAllocating:
		return 1
	case BattlePhaseReady:
		return 2
	case BattlePhaseEntering:
		return 3
	case BattlePhaseActive:
		return 4
	case BattlePhaseReturning:
		return 5
	case BattlePhaseCompleted, "failed", "cancelled":
		return 6
	default:
		return 0
	}
}

func (s *Service) applyQueueStatusResult(target queueSyncTarget, result gameclient.GetPartyQueueStatusResult) (*SnapshotProjection, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil, false
	}
	if room.QueueState.QueueEntryID != target.queueEntryID {
		return nil, false
	}
	if !shouldSyncQueueState(room.QueueState.Phase) {
		return nil, false
	}
	if isProtectedBattleRoomPhase(room.RoomState.Phase) && !isAuthoritativeMatchFinalizedForRoom(room, result) {
		return nil, false
	}

	changed := applyPartyQueueProjection(room, result, s.roomOwnerByID[target.roomID])
	if !changed {
		return nil, false
	}

	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), true
}

func isAuthoritativeMatchFinalizedForRoom(room *domain.RoomAggregate, result gameclient.GetPartyQueueStatusResult) bool {
	if room == nil {
		return false
	}
	queuePhase, terminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	if queuePhase != QueuePhaseCompleted || terminalReason != QueueReasonMatchFinalized {
		return false
	}
	resultAssignmentID := strings.TrimSpace(result.AssignmentID)
	resultBattleID := strings.TrimSpace(result.BattleID)
	resultMatchID := strings.TrimSpace(result.MatchID)
	if resultAssignmentID == "" && resultBattleID == "" && resultMatchID == "" {
		return false
	}
	if resultAssignmentID != "" && room.BattleState.AssignmentID != "" && resultAssignmentID != room.BattleState.AssignmentID {
		return false
	}
	if resultBattleID != "" && room.BattleState.BattleID != "" && resultBattleID != room.BattleState.BattleID {
		return false
	}
	if resultMatchID != "" && room.BattleState.MatchID != "" && resultMatchID != room.BattleState.MatchID {
		return false
	}
	return true
}

func allMembersReady(members map[string]domain.RoomMember) bool {
	if len(members) == 0 {
		return false
	}
	for _, member := range members {
		if member.MemberPhase != MemberPhaseReady {
			return false
		}
	}
	return true
}

func nonOwnerMembersReady(members map[string]domain.RoomMember, ownerMemberID string) bool {
	if len(members) < 2 {
		return false
	}
	for memberID, member := range members {
		if memberID == ownerMemberID {
			continue
		}
		if member.MemberPhase != MemberPhaseReady {
			return false
		}
	}
	return true
}

func selectNextRoomOwner(members map[string]domain.RoomMember) string {
	nextOwnerID := ""
	nextSlot := int(^uint(0) >> 1)
	for memberID, member := range members {
		slotIndex := member.SlotIndex
		if slotIndex < 0 {
			slotIndex = nextSlot
		}
		if nextOwnerID == "" || slotIndex < nextSlot || (slotIndex == nextSlot && memberID < nextOwnerID) {
			nextOwnerID = memberID
			nextSlot = slotIndex
		}
	}
	return nextOwnerID
}

func buildPartyMembers(members map[string]domain.RoomMember) []gameclient.PartyMember {
	result := make([]gameclient.PartyMember, 0, len(members))
	for _, member := range members {
		result = append(result, gameclient.PartyMember{
			AccountID:       member.AccountID,
			ProfileID:       member.ProfileID,
			TeamID:          member.TeamID,
			CharacterID:     member.Loadout.CharacterID,
			BubbleStyleID:   member.Loadout.BubbleStyleID,
		})
	}
	return result
}

func isBattleEntryReadyStatus(result gameclient.GetPartyQueueStatusResult) bool {
	if result.BattleEntryReady {
		return true
	}
	if strings.TrimSpace(result.AssignmentID) == "" || strings.TrimSpace(result.BattleID) == "" {
		return false
	}
	return strings.TrimSpace(result.ServerHost) != "" && result.ServerPort > 0
}

func isManualBattleAllocationReady(allocationState string, serverHost string, serverPort int) bool {
	switch strings.TrimSpace(allocationState) {
	case "ready", "bound_ready", "battle_ready":
		return strings.TrimSpace(serverHost) != "" && serverPort > 0
	default:
		return false
	}
}

func isBattleAssignmentGone(result gameclient.GetBattleAssignmentStatusResult) bool {
	code := strings.ToUpper(strings.TrimSpace(result.ErrorCode))
	switch code {
	case "ASSIGNMENT_NOT_FOUND", "BATTLE_NOT_FOUND", "BATTLE_REAPED", "BATTLE_FINALIZED", "NOT_FOUND", "GONE":
		return true
	case "GET_ASSIGNMENT_STATUS_FAILED":
		message := strings.ToLower(strings.TrimSpace(result.UserMessage))
		return strings.Contains(message, "not found") || strings.Contains(message, "reaped") || strings.Contains(message, "finalized")
	default:
		return false
	}
}

func (s *Service) logBattleProjectionIgnoredLocked(room *domain.RoomAggregate, result gameclient.GetBattleAssignmentStatusResult) {
	if s == nil || s.logger == nil || room == nil {
		return
	}
	s.logger.Debug(
		"battle assignment projection ignored",
		"event", "battle_assignment_projection_ignored_protected_phase",
		"room_id", room.RoomID,
		"room_kind", room.RoomKind,
		"room_phase", room.RoomState.Phase,
		"battle_phase", room.BattleState.Phase,
		"assignment_id", room.BattleState.AssignmentID,
		"assignment_revision", room.BattleState.AssignmentRevision,
		"result_battle_phase", result.BattlePhase,
		"result_terminal_reason", result.TerminalReason,
		"result_finalized", result.Finalized,
		"result_assignment_revision", result.AssignmentRevision,
	)
}

func clearBattleStateProjection(handoff *domain.BattleHandoffFSMProjection) bool {
	if handoff == nil {
		return false
	}
	changed := false
	if handoff.AssignmentID != "" {
		handoff.AssignmentID = ""
		changed = true
	}
	if handoff.AssignmentRevision != 0 {
		handoff.AssignmentRevision = 0
		changed = true
	}
	if handoff.MatchID != "" {
		handoff.MatchID = ""
		changed = true
	}
	if handoff.BattleID != "" {
		handoff.BattleID = ""
		changed = true
	}
	if handoff.ServerHost != "" {
		handoff.ServerHost = ""
		changed = true
	}
	if handoff.ServerPort != 0 {
		handoff.ServerPort = 0
		changed = true
	}
	if handoff.Ready {
		handoff.Ready = false
		changed = true
	}
	if handoff.Phase != BattlePhaseCompleted {
		handoff.Phase = BattlePhaseCompleted
		changed = true
	}
	if handoff.TerminalReason == "" {
		handoff.TerminalReason = BattleReasonNone
		changed = true
	}
	return changed
}

func (s *Service) syncDirectoryEntryLocked(room *domain.RoomAggregate) {
	if s == nil || s.registry == nil || room == nil {
		return
	}
	if !isDirectoryVisibleRoomKind(room.RoomKind) {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	if isBattleRoomEmpty(room) {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	if room.RoomState.Phase == RoomPhaseBattleEntryReady ||
		room.RoomState.Phase == RoomPhaseBattleEntering ||
		room.RoomState.Phase == RoomPhaseInBattle {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	memberCount := len(room.Members)
	_, hasAvailableSlot := firstAvailableSlot(room.OpenSlotIndices, room.Members)
	joinable := hasAvailableSlot &&
		!canCancelQueueFromState(room.QueueState.Phase)
	s.registry.UpsertRoomEntry(registry.DirectoryEntry{
		RoomID:          room.RoomID,
		RoomDisplayName: room.RoomDisplayName,
		RoomKind:        room.RoomKind,
		ModeID:          room.Selection.ModeID,
		MapID:           room.Selection.MapID,
		MemberCount:     int32(memberCount),
		MaxPlayerCount:  int32(room.MaxPlayerCount),
		Joinable:        joinable,
	})
}

func defaultOpenSlotIndices(maxPlayerCount int) []int {
	if maxPlayerCount <= 0 {
		return []int{}
	}
	result := make([]int, 0, maxPlayerCount)
	for slotIndex := 0; slotIndex < maxPlayerCount; slotIndex++ {
		result = append(result, slotIndex)
	}
	return result
}

func firstAvailableSlot(openSlotIndices []int, members map[string]domain.RoomMember) (int, bool) {
	occupied := occupiedSlotSet(members)
	normalized := normalizeSlotSet(openSlotIndices)
	for _, slotIndex := range normalized {
		if !occupied[slotIndex] {
			return slotIndex, true
		}
	}
	return 0, false
}

func normalizeOpenSlotIndices(requested []int, maxPlayerCount int, members map[string]domain.RoomMember) ([]int, error) {
	if maxPlayerCount <= 0 {
		return nil, ErrInvalidSelection
	}
	occupied := occupiedSlotSet(members)
	slotSet := map[int]struct{}{}
	for _, slotIndex := range requested {
		if slotIndex < 0 || slotIndex >= maxPlayerCount {
			return nil, ErrInvalidSelection
		}
		slotSet[slotIndex] = struct{}{}
	}
	for slotIndex := range occupied {
		if slotIndex < 0 || slotIndex >= maxPlayerCount {
			return nil, ErrInvalidSelection
		}
		slotSet[slotIndex] = struct{}{}
	}
	requiredOpenCount := len(occupied)
	if requiredOpenCount < 2 {
		requiredOpenCount = 2
	}
	if len(slotSet) < requiredOpenCount {
		return nil, ErrInvalidSelection
	}
	return sortedSlotSet(slotSet), nil
}

func expandOpenSlotIndices(current []int, maxPlayerCount int, members map[string]domain.RoomMember) []int {
	if maxPlayerCount <= 0 {
		return []int{}
	}
	slotSet := map[int]struct{}{}
	for _, slotIndex := range current {
		if slotIndex >= 0 && slotIndex < maxPlayerCount {
			slotSet[slotIndex] = struct{}{}
		}
	}
	for slotIndex := range occupiedSlotSet(members) {
		if slotIndex >= 0 && slotIndex < maxPlayerCount {
			slotSet[slotIndex] = struct{}{}
		}
	}
	for slotIndex := 0; len(slotSet) < 2 && slotIndex < maxPlayerCount; slotIndex++ {
		slotSet[slotIndex] = struct{}{}
	}
	return sortedSlotSet(slotSet)
}

func occupiedSlotSet(members map[string]domain.RoomMember) map[int]bool {
	result := map[int]bool{}
	for _, member := range members {
		if member.SlotIndex >= 0 {
			result[member.SlotIndex] = true
		}
	}
	return result
}

func normalizeSlotSet(slots []int) []int {
	slotSet := map[int]struct{}{}
	for _, slotIndex := range slots {
		if slotIndex >= 0 {
			slotSet[slotIndex] = struct{}{}
		}
	}
	return sortedSlotSet(slotSet)
}

func sortedSlotSet(slotSet map[int]struct{}) []int {
	result := make([]int, 0, len(slotSet))
	for slotIndex := range slotSet {
		result = append(result, slotIndex)
	}
	for i := 1; i < len(result); i++ {
		value := result[i]
		j := i - 1
		for j >= 0 && result[j] > value {
			result[j+1] = result[j]
			j--
		}
		result[j+1] = value
	}
	return result
}

func (s *Service) touchRoomSnapshotLocked(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	room.SnapshotRevision++
	room.RoomState.Revision = room.SnapshotRevision
	syncLegacyAliases(room)
	rebuildRoomCapabilities(room, s.roomOwnerByID[room.RoomID], s.query)
}

func legacyQueueStateToCanonical(legacy string) (string, string) {
	switch strings.TrimSpace(legacy) {
	case "queueing":
		return QueuePhaseQueued, queueReasonLegacyQueueingAlias
	case "queued":
		return QueuePhaseQueued, QueueReasonNone
	case "assigned", "committing":
		return QueuePhaseAssignmentPending, QueueReasonNone
	case "allocating":
		return QueuePhaseAllocatingBattle, QueueReasonNone
	case "battle_ready", "matched":
		return QueuePhaseEntryReady, QueueReasonNone
	case "cancelled":
		return QueuePhaseCompleted, QueueReasonClientCancelled
	case "expired":
		return QueuePhaseCompleted, QueueReasonAssignmentExpired
	case "failed":
		return QueuePhaseCompleted, QueueReasonAllocationFailed
	case "finalized":
		return QueuePhaseCompleted, QueueReasonMatchFinalized
	case "", "idle":
		return QueuePhaseIdle, QueueReasonNone
	default:
		return QueuePhaseCompleted, QueueReasonAllocationFailed
	}
}

func resolveQueuePhaseAndTerminalReason(queuePhase string, terminalReason string, legacyQueueState string, ok bool) (string, string) {
	queuePhase = strings.TrimSpace(queuePhase)
	terminalReason = strings.TrimSpace(terminalReason)
	if queuePhase == "" {
		queuePhase, terminalReason = legacyQueueStateToCanonical(legacyQueueState)
	}
	if !ok && (queuePhase == "" || queuePhase == QueuePhaseIdle) {
		queuePhase = QueuePhaseCompleted
	}
	if queuePhase == QueuePhaseCompleted && (terminalReason == "" || terminalReason == QueueReasonNone || terminalReason == queueReasonLegacyQueueingAlias) {
		_, fallbackReason := legacyQueueStateToCanonical(legacyQueueState)
		terminalReason = fallbackReason
		if terminalReason == "" || terminalReason == QueueReasonNone || terminalReason == queueReasonLegacyQueueingAlias {
			terminalReason = QueueReasonAllocationFailed
		}
	}
	if queuePhase != QueuePhaseCompleted && terminalReason == "" {
		terminalReason = QueueReasonNone
	}
	return queuePhase, terminalReason
}

func resolveQueueStatusText(queueStatusText string, fallbackStatusText string, legacyQueueState string) string {
	if value := strings.TrimSpace(queueStatusText); value != "" {
		return value
	}
	if value := strings.TrimSpace(fallbackStatusText); value != "" {
		return value
	}
	return strings.TrimSpace(legacyQueueState)
}

func nextQueuePhaseToBattlePhase(queuePhase string) string {
	switch queuePhase {
	case QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle:
		return BattlePhaseAllocating
	case QueuePhaseEntryReady:
		return BattlePhaseReady
	case QueuePhaseCompleted, QueuePhaseIdle:
		return BattlePhaseCompleted
	default:
		return BattlePhaseIdle
	}
}
