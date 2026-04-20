package queue

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	mathrand "math/rand"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/game_service/internal/storage"
)

var (
	ErrQueueAlreadyActive      = errors.New("MATCHMAKING_QUEUE_ALREADY_ACTIVE")
	ErrQueueNotFound           = errors.New("MATCHMAKING_QUEUE_NOT_FOUND")
	ErrPartySizeMismatch       = errors.New("MATCHMAKING_PARTY_SIZE_MISMATCH")
	ErrQueueTypeInvalid        = errors.New("MATCHMAKING_QUEUE_TYPE_INVALID")
	ErrModeInvalid             = errors.New("MATCHMAKING_MODE_INVALID")
	ErrRuleSetInvalid          = errors.New("MATCHMAKING_RULE_SET_INVALID")
	ErrAssignmentExpired       = errors.New("MATCHMAKING_ASSIGNMENT_EXPIRED")
	ErrAssignmentRevisionStale = errors.New("MATCHMAKING_ASSIGNMENT_REVISION_STALE")
)

// BattleAllocator allocates a DS instance for a battle.
// Implemented by battlealloc.Service; defined here to avoid circular imports.
type BattleAllocator interface {
	AllocateBattle(ctx context.Context, input BattleAllocateInput) (BattleAllocateResult, error)
}

type BattleAllocateInput struct {
	AssignmentID        string
	BattleID            string
	MatchID             string
	SourceRoomID        string
	SourceRoomKind      string
	ModeID              string
	RuleSetID           string
	MapID               string
	ExpectedMemberCount int
	HostHint            string
}

type BattleAllocateResult struct {
	BattleID        string
	DSInstanceID    string
	ServerHost      string
	ServerPort      int
	AllocationState string
}

type Service struct {
	queueRepo              *storage.QueueRepository
	partyQueueRepo         *storage.PartyQueueRepository
	partyQueueMemberRepo   *storage.PartyQueueMemberRepository
	assignmentRepo         *storage.AssignmentRepository
	txPool                 *pgxpool.Pool
	ratingRepo             *storage.RatingRepository
	battleAllocator        BattleAllocator
	heartbeatTTL           time.Duration
	defaultSeasonID        string
	defaultMapID           string
	defaultDSHost          string
	defaultDSPort          int
	captainDeadlineSeconds int
	commitDeadlineSeconds  int
}

func NewService(queueRepo *storage.QueueRepository, assignmentRepo *storage.AssignmentRepository, txPool *pgxpool.Pool, heartbeatTTL time.Duration) *Service {
	defaults := DefaultAssignmentDefaults()
	return &Service{
		queueRepo:              queueRepo,
		assignmentRepo:         assignmentRepo,
		txPool:                 txPool,
		heartbeatTTL:           heartbeatTTL,
		defaultSeasonID:        defaults.SeasonID,
		defaultMapID:           defaults.MapID,
		defaultDSHost:          defaults.DSHost,
		defaultDSPort:          defaults.DSPort,
		captainDeadlineSeconds: defaults.CaptainDeadlineSeconds,
		commitDeadlineSeconds:  defaults.CommitDeadlineSeconds,
	}
}

func (s *Service) ConfigureAssignmentDefaults(defaultDSHost string, defaultDSPort int, captainDeadlineSeconds int, commitDeadlineSeconds int) {
	s.ConfigureDefaults(AssignmentDefaults{
		DSHost:                 defaultDSHost,
		DSPort:                 defaultDSPort,
		CaptainDeadlineSeconds: captainDeadlineSeconds,
		CommitDeadlineSeconds:  commitDeadlineSeconds,
	})
}

func (s *Service) ConfigureDefaults(defaults AssignmentDefaults) {
	normalized := NormalizeAssignmentDefaults(defaults)
	s.defaultSeasonID = normalized.SeasonID
	s.defaultMapID = normalized.MapID
	s.defaultDSHost = normalized.DSHost
	s.defaultDSPort = normalized.DSPort
	s.captainDeadlineSeconds = normalized.CaptainDeadlineSeconds
	s.commitDeadlineSeconds = normalized.CommitDeadlineSeconds
}

func (s *Service) ConfigureRatingRepository(ratingRepo *storage.RatingRepository) {
	s.ratingRepo = ratingRepo
}

func (s *Service) ConfigurePartyQueueRepositories(partyQueueRepo *storage.PartyQueueRepository, partyQueueMemberRepo *storage.PartyQueueMemberRepository) {
	s.partyQueueRepo = partyQueueRepo
	s.partyQueueMemberRepo = partyQueueMemberRepo
}

func (s *Service) ConfigureBattleAllocator(allocator BattleAllocator) {
	s.battleAllocator = allocator
}

func (s *Service) EnterQueue(ctx context.Context, input EnterQueueInput) (QueueStatus, error) {
	if input.QueueType != "casual" && input.QueueType != "ranked" {
		return QueueStatus{}, ErrQueueTypeInvalid
	}
	if input.ModeID == "" {
		return QueueStatus{}, ErrModeInvalid
	}
	if input.RuleSetID == "" {
		return QueueStatus{}, ErrRuleSetInvalid
	}

	if _, err := s.queueRepo.FindActiveByProfileID(ctx, input.ProfileID); err == nil {
		return QueueStatus{}, ErrQueueAlreadyActive
	} else if !errors.Is(err, storage.ErrNotFound) {
		return QueueStatus{}, err
	}

	now := time.Now().UTC()
	seasonID := s.defaultSeasonID
	ratingSnapshot, err := s.resolveRatingSnapshot(ctx, seasonID, input.AccountID)
	if err != nil {
		return QueueStatus{}, err
	}
	entryID, err := opaqueID("queue")
	if err != nil {
		return QueueStatus{}, err
	}
	entry := storage.QueueEntry{
		QueueEntryID:         entryID,
		QueueType:            input.QueueType,
		QueueKey:             BuildQueueKey(input.QueueType, input.MatchFormatID, input.ModeID, input.RuleSetID),
		SeasonID:             seasonID,
		AccountID:            input.AccountID,
		ProfileID:            input.ProfileID,
		DeviceSessionID:      input.DeviceSessionID,
		ModeID:               input.ModeID,
		RuleSetID:            input.RuleSetID,
		PreferredMapPoolID:   input.PreferredMapPoolID,
		RatingSnapshot:       ratingSnapshot,
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		State:                "queued",
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	if err := s.queueRepo.Insert(ctx, entry); err != nil {
		if storage.IsConstraintViolation(err, "uq_matchmaking_queue_entries_profile_active") {
			return QueueStatus{}, ErrQueueAlreadyActive
		}
		return QueueStatus{}, err
	}
	if err := s.tryFormAssignment(ctx, entry); err != nil {
		return QueueStatus{}, err
	}
	if assignedStatus, err := s.GetStatus(ctx, input.ProfileID, entry.QueueEntryID); err == nil && assignedStatus.QueueState == "assigned" {
		return assignedStatus, nil
	}
	return s.buildQueuedStatus(entry), nil
}

func (s *Service) EnterPartyQueue(ctx context.Context, input EnterPartyQueueInput) (PartyQueueStatus, error) {
	if input.QueueType != "casual" && input.QueueType != "ranked" {
		return PartyQueueStatus{}, ErrQueueTypeInvalid
	}
	if input.PartyRoomID == "" || len(input.Members) == 0 {
		return PartyQueueStatus{}, ErrQueueNotFound
	}
	if len(input.SelectedModeIDs) == 0 {
		return PartyQueueStatus{}, ErrModeInvalid
	}
	requiredPartySize := requiredPartySizeFromMatchFormat(input.MatchFormatID)
	if requiredPartySize <= 0 || len(input.Members) != requiredPartySize {
		return PartyQueueStatus{}, ErrPartySizeMismatch
	}
	if s.partyQueueRepo == nil || s.partyQueueMemberRepo == nil {
		return PartyQueueStatus{}, ErrQueueNotFound
	}
	if _, err := s.partyQueueRepo.FindActiveByRoomID(ctx, input.PartyRoomID); err == nil {
		return PartyQueueStatus{}, ErrQueueAlreadyActive
	} else if !errors.Is(err, storage.ErrNotFound) {
		return PartyQueueStatus{}, err
	}

	now := time.Now().UTC()
	entryID, err := opaqueID("party_queue")
	if err != nil {
		return PartyQueueStatus{}, err
	}
	captain := input.Members[0]
	entry := storage.PartyQueueEntry{
		PartyQueueEntryID:    entryID,
		PartyRoomID:          input.PartyRoomID,
		QueueType:            input.QueueType,
		MatchFormatID:        normalizeMatchFormatID(input.MatchFormatID),
		PartySize:            len(input.Members),
		CaptainAccountID:     captain.AccountID,
		CaptainProfileID:     captain.ProfileID,
		SelectedModeIDs:      normalizeModeIDs(input.SelectedModeIDs),
		QueueKey:             BuildPartyQueueKey(input.QueueType, input.MatchFormatID),
		State:                "queued",
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	if err := s.partyQueueRepo.Insert(ctx, entry); err != nil {
		if storage.IsConstraintViolation(err, "uq_matchmaking_party_queue_entries_room_active") {
			return PartyQueueStatus{}, ErrQueueAlreadyActive
		}
		return PartyQueueStatus{}, err
	}
	for idx, memberInput := range input.Members {
		ratingSnapshot := memberInput.RatingSnapshot
		if ratingSnapshot <= 0 {
			var err error
			ratingSnapshot, err = s.resolveRatingSnapshot(ctx, s.defaultSeasonID, memberInput.AccountID)
			if err != nil {
				return PartyQueueStatus{}, err
			}
		}
		member := storage.PartyQueueMember{
			PartyQueueEntryID: entryID,
			AccountID:         memberInput.AccountID,
			ProfileID:         memberInput.ProfileID,
			DeviceSessionID:   memberInput.DeviceSessionID,
			SeatIndex:         idx,
			RatingSnapshot:    ratingSnapshot,
			CreatedAt:         now,
			UpdatedAt:         now,
		}
		if err := s.partyQueueMemberRepo.Insert(ctx, member); err != nil {
			return PartyQueueStatus{}, err
		}
	}
	if err := s.tryFormPartyAssignment(ctx, entry); err != nil {
		return PartyQueueStatus{}, err
	}
	if assignedStatus, err := s.GetPartyQueueStatus(ctx, input.PartyRoomID, entry.PartyQueueEntryID); err == nil && assignedStatus.QueueState == "assigned" {
		return assignedStatus, nil
	}
	return s.buildPartyQueuedStatus(entry), nil
}

func (s *Service) CancelPartyQueue(ctx context.Context, partyRoomID string, queueEntryID string) (PartyQueueStatus, error) {
	entry, err := s.findPartyEntry(ctx, partyRoomID, queueEntryID)
	if err != nil {
		return PartyQueueStatus{}, err
	}
	nowUnix := time.Now().UTC().Unix()
	if err := s.partyQueueRepo.UpdateStatus(ctx, entry.PartyQueueEntryID, "cancelled", "party_cancelled", entry.AssignmentID, entry.AssignmentRevision, nowUnix); err != nil {
		return PartyQueueStatus{}, err
	}
	entry.State = "cancelled"
	entry.LastHeartbeatUnixSec = nowUnix
	entry.CancelReason = "party_cancelled"
	return s.buildPartyQueuedStatus(entry), nil
}

func (s *Service) GetPartyQueueStatus(ctx context.Context, partyRoomID string, queueEntryID string) (PartyQueueStatus, error) {
	entry, err := s.findPartyEntry(ctx, partyRoomID, queueEntryID)
	if err != nil {
		return PartyQueueStatus{}, err
	}
	now := time.Now().UTC()
	if entry.LastHeartbeatUnixSec+int64(s.heartbeatTTL.Seconds()) < now.Unix() {
		if err := s.partyQueueRepo.UpdateStatus(ctx, entry.PartyQueueEntryID, "cancelled", "heartbeat_timeout", entry.AssignmentID, entry.AssignmentRevision, now.Unix()); err != nil {
			return PartyQueueStatus{}, err
		}
		entry.State = "cancelled"
		return s.buildPartyQueuedStatus(entry), nil
	}
	if entry.State == "queued" {
		_ = s.partyQueueRepo.UpdateStatus(ctx, entry.PartyQueueEntryID, entry.State, entry.CancelReason, entry.AssignmentID, entry.AssignmentRevision, now.Unix())
		entry.LastHeartbeatUnixSec = now.Unix()
		return s.buildPartyQueuedStatus(entry), nil
	}
	assignment, err := s.assignmentRepo.FindByID(ctx, entry.AssignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return PartyQueueStatus{}, ErrAssignmentExpired
		}
		return PartyQueueStatus{}, err
	}
	if assignment.CommitDeadlineUnixSec < now.Unix() {
		return PartyQueueStatus{}, ErrAssignmentExpired
	}
	_ = s.partyQueueRepo.UpdateStatus(ctx, entry.PartyQueueEntryID, entry.State, entry.CancelReason, entry.AssignmentID, entry.AssignmentRevision, now.Unix())
	resolvedHost, resolvedPort := resolveAssignmentServerEndpoint(assignment)
	assignmentStatusText := resolveAssignmentStatusText(assignment, "Waiting for room ticket")
	return PartyQueueStatus{
		QueueState:             entry.State,
		QueueEntryID:           entry.PartyQueueEntryID,
		PartyRoomID:            entry.PartyRoomID,
		QueueKey:               entry.QueueKey,
		QueueType:              entry.QueueType,
		MatchFormatID:          entry.MatchFormatID,
		SelectedModeIDs:        entry.SelectedModeIDs,
		AssignmentID:           assignment.AssignmentID,
		AssignmentRevision:     assignment.AssignmentRevision,
		QueueStatusText:        "Match found",
		AssignmentStatusText:   assignmentStatusText,
		EnqueueUnixSec:         entry.EnqueueUnixSec,
		LastHeartbeatUnixSec:   now.Unix(),
		ExpiresAtUnixSec:       now.Unix() + int64(s.heartbeatTTL.Seconds()),
		RoomID:                 assignment.RoomID,
		RoomKind:               assignment.RoomKind,
		ServerHost:             resolvedHost,
		ServerPort:             resolvedPort,
		ModeID:                 assignment.ModeID,
		RuleSetID:              assignment.RuleSetID,
		MapID:                  assignment.MapID,
		CaptainAccountID:       assignment.CaptainAccountID,
		CaptainDeadlineUnixSec: assignment.CaptainDeadlineUnixSec,
		CommitDeadlineUnixSec:  assignment.CommitDeadlineUnixSec,
		BattleID:               assignment.BattleID,
		MatchID:                assignment.MatchID,
		AllocationState:        assignment.AllocationState,
	}, nil
}

func (s *Service) CancelQueue(ctx context.Context, profileID string, queueEntryID string) (QueueStatus, error) {
	entry, err := s.findOwnedEntry(ctx, profileID, queueEntryID)
	if err != nil {
		return QueueStatus{}, err
	}
	nowUnix := time.Now().UTC().Unix()
	if entry.State == "assigned" || entry.State == "committing" {
		assignment, err := s.assignmentRepo.FindByID(ctx, entry.AssignmentID)
		if err != nil && !errors.Is(err, storage.ErrNotFound) {
			return QueueStatus{}, err
		}
		if err == nil && assignment.AssignmentRevision != entry.AssignmentRevision {
			return QueueStatus{}, ErrAssignmentRevisionStale
		}
	}
	if err := s.queueRepo.UpdateStatus(ctx, entry.QueueEntryID, "cancelled", "client_cancelled", entry.AssignmentID, entry.AssignmentRevision, nowUnix); err != nil {
		return QueueStatus{}, err
	}
	return QueueStatus{
		QueueState:   "cancelled",
		QueueEntryID: entry.QueueEntryID,
	}, nil
}

func (s *Service) GetStatus(ctx context.Context, profileID string, queueEntryID string) (QueueStatus, error) {
	entry, err := s.findOwnedEntry(ctx, profileID, queueEntryID)
	if err != nil {
		return QueueStatus{}, err
	}
	now := time.Now().UTC()
	if entry.LastHeartbeatUnixSec+int64(s.heartbeatTTL.Seconds()) < now.Unix() {
		if err := s.queueRepo.UpdateStatus(ctx, entry.QueueEntryID, "cancelled", "heartbeat_timeout", entry.AssignmentID, entry.AssignmentRevision, now.Unix()); err != nil {
			return QueueStatus{}, err
		}
		return QueueStatus{QueueState: "cancelled", QueueEntryID: entry.QueueEntryID}, nil
	}
	if entry.State == "queued" {
		_ = s.queueRepo.UpdateStatus(ctx, entry.QueueEntryID, entry.State, entry.CancelReason, entry.AssignmentID, entry.AssignmentRevision, now.Unix())
		entry.LastHeartbeatUnixSec = now.Unix()
		return s.buildQueuedStatus(entry), nil
	}
	assignment, err := s.assignmentRepo.FindByID(ctx, entry.AssignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return QueueStatus{}, ErrAssignmentExpired
		}
		return QueueStatus{}, err
	}
	if assignment.CommitDeadlineUnixSec < now.Unix() {
		return QueueStatus{}, ErrAssignmentExpired
	}
	assignment, entry, err = s.reElectCaptainForStatusIfNeeded(ctx, assignment, entry, now)
	if err != nil {
		return QueueStatus{}, err
	}
	member, err := s.assignmentRepo.FindMember(ctx, entry.AssignmentID, entry.AccountID)
	if err != nil {
		return QueueStatus{}, err
	}
	if assignment.AssignmentRevision != entry.AssignmentRevision {
		return QueueStatus{}, ErrAssignmentRevisionStale
	}
	_ = s.queueRepo.UpdateStatus(ctx, entry.QueueEntryID, entry.State, entry.CancelReason, entry.AssignmentID, entry.AssignmentRevision, now.Unix())
	resolvedHost, resolvedPort := resolveAssignmentServerEndpoint(assignment)
	assignmentStatusText := resolveAssignmentStatusText(assignment, "Waiting for ticket request")
	return QueueStatus{
		QueueState:             entry.State,
		QueueEntryID:           entry.QueueEntryID,
		QueueKey:               entry.QueueKey,
		AssignmentID:           assignment.AssignmentID,
		AssignmentRevision:     assignment.AssignmentRevision,
		QueueStatusText:        "Match found",
		AssignmentStatusText:   assignmentStatusText,
		EnqueueUnixSec:         entry.EnqueueUnixSec,
		LastHeartbeatUnixSec:   now.Unix(),
		ExpiresAtUnixSec:       now.Unix() + int64(s.heartbeatTTL.Seconds()),
		TicketRole:             member.TicketRole,
		RoomID:                 assignment.RoomID,
		RoomKind:               assignment.RoomKind,
		ServerHost:             resolvedHost,
		ServerPort:             resolvedPort,
		ModeID:                 assignment.ModeID,
		RuleSetID:              assignment.RuleSetID,
		MapID:                  assignment.MapID,
		AssignedTeamID:         member.AssignedTeamID,
		CaptainAccountID:       assignment.CaptainAccountID,
		CaptainDeadlineUnixSec: assignment.CaptainDeadlineUnixSec,
		CommitDeadlineUnixSec:  assignment.CommitDeadlineUnixSec,
	}, nil
}

func (s *Service) buildQueuedStatus(entry storage.QueueEntry) QueueStatus {
	return QueueStatus{
		QueueState:           entry.State,
		QueueEntryID:         entry.QueueEntryID,
		QueueKey:             entry.QueueKey,
		AssignmentID:         entry.AssignmentID,
		AssignmentRevision:   entry.AssignmentRevision,
		QueueStatusText:      "Searching for players",
		AssignmentStatusText: "",
		EnqueueUnixSec:       entry.EnqueueUnixSec,
		LastHeartbeatUnixSec: entry.LastHeartbeatUnixSec,
		ExpiresAtUnixSec:     entry.LastHeartbeatUnixSec + int64(s.heartbeatTTL.Seconds()),
	}
}

func (s *Service) buildPartyQueuedStatus(entry storage.PartyQueueEntry) PartyQueueStatus {
	statusText := "Searching for teams"
	if entry.State == "cancelled" {
		statusText = "Queue cancelled"
	}
	return PartyQueueStatus{
		QueueState:           entry.State,
		QueueEntryID:         entry.PartyQueueEntryID,
		PartyRoomID:          entry.PartyRoomID,
		QueueKey:             entry.QueueKey,
		QueueType:            entry.QueueType,
		MatchFormatID:        entry.MatchFormatID,
		SelectedModeIDs:      entry.SelectedModeIDs,
		AssignmentID:         entry.AssignmentID,
		AssignmentRevision:   entry.AssignmentRevision,
		QueueStatusText:      statusText,
		AssignmentStatusText: "",
		EnqueueUnixSec:       entry.EnqueueUnixSec,
		LastHeartbeatUnixSec: entry.LastHeartbeatUnixSec,
		ExpiresAtUnixSec:     entry.LastHeartbeatUnixSec + int64(s.heartbeatTTL.Seconds()),
	}
}

func (s *Service) findOwnedEntry(ctx context.Context, profileID string, queueEntryID string) (storage.QueueEntry, error) {
	var entry storage.QueueEntry
	var err error
	if queueEntryID != "" {
		entry, err = s.queueRepo.FindByQueueEntryID(ctx, queueEntryID)
	} else {
		entry, err = s.queueRepo.FindActiveByProfileID(ctx, profileID)
	}
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return storage.QueueEntry{}, ErrQueueNotFound
		}
		return storage.QueueEntry{}, err
	}
	if entry.ProfileID != profileID {
		return storage.QueueEntry{}, ErrQueueNotFound
	}
	return entry, nil
}

func (s *Service) findPartyEntry(ctx context.Context, partyRoomID string, queueEntryID string) (storage.PartyQueueEntry, error) {
	var entry storage.PartyQueueEntry
	var err error
	if queueEntryID != "" {
		entry, err = s.partyQueueRepo.FindByEntryID(ctx, queueEntryID)
	} else {
		entry, err = s.partyQueueRepo.FindActiveByRoomID(ctx, partyRoomID)
	}
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return storage.PartyQueueEntry{}, ErrQueueNotFound
		}
		return storage.PartyQueueEntry{}, err
	}
	if partyRoomID != "" && entry.PartyRoomID != partyRoomID {
		return storage.PartyQueueEntry{}, ErrQueueNotFound
	}
	return entry, nil
}

func opaqueID(prefix string) (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return prefix + "_" + hex.EncodeToString(buf), nil
}

func (s *Service) tryFormAssignment(ctx context.Context, entry storage.QueueEntry) error {
	if s.assignmentRepo == nil {
		return nil
	}
	if s.txPool == nil {
		return s.tryFormAssignmentWithRepos(ctx, entry, s.queueRepo, s.assignmentRepo, false)
	}
	err := storage.WithTx(ctx, s.txPool, func(tx pgx.Tx) error {
		txQueueRepo := storage.NewQueueRepository(tx)
		txAssignmentRepo := storage.NewAssignmentRepository(tx)
		return s.tryFormAssignmentWithRepos(ctx, entry, txQueueRepo, txAssignmentRepo, true)
	})
	if errors.Is(err, storage.ErrConcurrentStateChanged) {
		return nil
	}
	return err
}

// pendingBattleAlloc holds the data needed to allocate a DS after the
// assignment transaction commits.
type pendingBattleAlloc struct {
	AssignmentID        string
	BattleID            string
	MatchID             string
	SourceRoomID        string
	SourceRoomKind      string
	ModeID              string
	RuleSetID           string
	MapID               string
	ExpectedMemberCount int
}

func (s *Service) tryFormPartyAssignment(ctx context.Context, entry storage.PartyQueueEntry) error {
	if s.assignmentRepo == nil || s.partyQueueRepo == nil || s.partyQueueMemberRepo == nil {
		return nil
	}

	var pending *pendingBattleAlloc

	if s.txPool == nil {
		p, err := s.tryFormPartyAssignmentWithRepos(ctx, entry, s.partyQueueRepo, s.partyQueueMemberRepo, s.assignmentRepo, false)
		if err != nil {
			return err
		}
		pending = p
	} else {
		err := storage.WithTx(ctx, s.txPool, func(tx pgx.Tx) error {
			txPartyRepo := storage.NewPartyQueueRepository(tx)
			txMemberRepo := storage.NewPartyQueueMemberRepository(tx)
			txAssignmentRepo := storage.NewAssignmentRepository(tx)
			p, err := s.tryFormPartyAssignmentWithRepos(ctx, entry, txPartyRepo, txMemberRepo, txAssignmentRepo, true)
			if err != nil {
				return err
			}
			pending = p
			return nil
		})
		if errors.Is(err, storage.ErrConcurrentStateChanged) {
			return nil
		}
		if err != nil {
			return err
		}
	}

	// After tx commits, allocate DS if an assignment was formed
	if pending != nil && s.battleAllocator != nil {
		result, err := s.battleAllocator.AllocateBattle(ctx, BattleAllocateInput{
			AssignmentID:        pending.AssignmentID,
			BattleID:            pending.BattleID,
			MatchID:             pending.MatchID,
			SourceRoomID:        pending.SourceRoomID,
			SourceRoomKind:      pending.SourceRoomKind,
			ModeID:              pending.ModeID,
			RuleSetID:           pending.RuleSetID,
			MapID:               pending.MapID,
			ExpectedMemberCount: pending.ExpectedMemberCount,
		})
		if err != nil {
			if s.assignmentRepo != nil {
				markErr := s.assignmentRepo.MarkAllocationFailed(
					ctx,
					pending.AssignmentID,
					pending.BattleID,
					deriveAllocationErrorCode(err),
					normalizeAllocationError(err),
				)
				if markErr != nil {
					return fmt.Errorf("mark allocation failed state: %w", markErr)
				}
			}
		} else if s.assignmentRepo != nil {
			updateErr := s.assignmentRepo.UpdateAllocationState(
				ctx,
				pending.AssignmentID,
				"allocated",
				result.BattleID,
				result.DSInstanceID,
				result.ServerHost,
				result.ServerPort,
			)
			if updateErr != nil {
				return fmt.Errorf("update allocation state allocated: %w", updateErr)
			}
		}
	}

	return nil
}

func (s *Service) tryFormPartyAssignmentWithRepos(ctx context.Context, entry storage.PartyQueueEntry, partyRepo *storage.PartyQueueRepository, memberRepo *storage.PartyQueueMemberRepository, assignmentRepo *storage.AssignmentRepository, lockCandidates bool) (*pendingBattleAlloc, error) {
	const candidateLimit = 32
	now := time.Now().UTC()
	minHeartbeatUnixSec := now.Add(-s.heartbeatTTL).Unix()
	var queuedEntries []storage.PartyQueueEntry
	var err error
	if lockCandidates {
		queuedEntries, err = partyRepo.FindQueuedByKeyForUpdate(ctx, entry.QueueKey, candidateLimit, minHeartbeatUnixSec)
	} else {
		queuedEntries, err = partyRepo.FindQueuedByKey(ctx, entry.QueueKey, candidateLimit, minHeartbeatUnixSec)
	}
	if err != nil {
		return nil, err
	}
	requiredPartySize := requiredPartySizeFromMatchFormat(entry.MatchFormatID)
	selected := selectCompatibleParties(queuedEntries, requiredPartySize)
	if len(selected) != 2 {
		return nil, nil
	}
	finalModeID := firstModeIntersection(selected[0].SelectedModeIDs, selected[1].SelectedModeIDs)
	if finalModeID == "" {
		return nil, nil
	}
	finalMapID, finalRuleSetID := resolveMapAndRuleForMode(s.defaultMapID, finalModeID)

	assignmentID, err := opaqueID("assign")
	if err != nil {
		return nil, err
	}
	matchID, err := opaqueID("match")
	if err != nil {
		return nil, err
	}
	battleID, err := opaqueID("battle")
	if err != nil {
		return nil, err
	}
	expectedMemberCount := requiredPartySize * 2
	sourceRoomKind := resolveMatchRoomKind(entry.QueueType)
	assignmentRecord := storage.Assignment{
		AssignmentID:           assignmentID,
		QueueKey:               entry.QueueKey,
		QueueType:              entry.QueueType,
		SeasonID:               s.defaultSeasonID,
		RoomID:                 entry.PartyRoomID,
		RoomKind:               sourceRoomKind,
		MatchID:                matchID,
		ModeID:                 finalModeID,
		RuleSetID:              finalRuleSetID,
		MapID:                  finalMapID,
		ServerHost:             "",
		ServerPort:             0,
		CaptainAccountID:       selected[0].CaptainAccountID,
		AssignmentRevision:     1,
		ExpectedMemberCount:    expectedMemberCount,
		State:                  "assigned",
		CaptainDeadlineUnixSec: now.Add(time.Duration(s.captainDeadlineSeconds) * time.Second).Unix(),
		CommitDeadlineUnixSec:  now.Add(time.Duration(s.commitDeadlineSeconds) * time.Second).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
		SourceRoomID:           entry.PartyRoomID,
		SourceRoomKind:         sourceRoomKind,
		BattleID:               battleID,
		AllocationState:        "allocating",
		RoomReturnPolicy:       "return_to_source_room",
	}
	if err := assignmentRepo.Insert(ctx, assignmentRecord); err != nil {
		return nil, err
	}
	for partyIndex, party := range selected {
		members, err := memberRepo.ListByEntryID(ctx, party.PartyQueueEntryID)
		if err != nil {
			return nil, err
		}
		for _, queuedMember := range members {
			role := "join"
			if queuedMember.AccountID == selected[0].CaptainAccountID {
				role = "create"
			}
			member := storage.AssignmentMember{
				AssignmentID:    assignmentID,
				AccountID:       queuedMember.AccountID,
				ProfileID:       queuedMember.ProfileID,
				TicketRole:      role,
				AssignedTeamID:  partyIndex + 1,
				RatingBefore:    queuedMember.RatingSnapshot,
				JoinState:       "assigned",
				ResultState:     "",
				CreatedAt:       now,
				UpdatedAt:       now,
				BattleJoinState: "assigned",
				RoomReturnState: "pending",
			}
			if err := assignmentRepo.InsertMember(ctx, member); err != nil {
				return nil, err
			}
		}
		if err := partyRepo.UpdateStatusIfCurrentState(ctx, party.PartyQueueEntryID, "queued", "assigned", "", assignmentID, 1, now.Unix()); err != nil {
			return nil, err
		}
	}
	return &pendingBattleAlloc{
		AssignmentID:        assignmentID,
		BattleID:            battleID,
		MatchID:             matchID,
		SourceRoomID:        entry.PartyRoomID,
		SourceRoomKind:      sourceRoomKind,
		ModeID:              finalModeID,
		RuleSetID:           finalRuleSetID,
		MapID:               finalMapID,
		ExpectedMemberCount: expectedMemberCount,
	}, nil
}

func (s *Service) tryFormAssignmentWithRepos(ctx context.Context, entry storage.QueueEntry, queueRepo *storage.QueueRepository, assignmentRepo *storage.AssignmentRepository, lockCandidates bool) error {
	const candidateLimit = 32
	expectedMemberCount := expectedMemberCountFromQueueKey(entry.QueueKey)
	now := time.Now().UTC()
	minHeartbeatUnixSec := now.Add(-s.heartbeatTTL).Unix()
	var queuedEntries []storage.QueueEntry
	var err error
	if lockCandidates {
		queuedEntries, err = queueRepo.FindQueuedByKeyForUpdate(ctx, entry.QueueKey, candidateLimit, minHeartbeatUnixSec)
	} else {
		queuedEntries, err = queueRepo.FindQueuedByKey(ctx, entry.QueueKey, candidateLimit, minHeartbeatUnixSec)
	}
	if err != nil {
		return err
	}
	queuedEntries = selectRatingCompatibleCandidates(queuedEntries, expectedMemberCount, now.Unix())
	if len(queuedEntries) < expectedMemberCount {
		return nil
	}

	assignmentID, err := opaqueID("assign")
	if err != nil {
		return err
	}
	roomID, err := opaqueID("room")
	if err != nil {
		return err
	}
	matchID, err := opaqueID("match")
	if err != nil {
		return err
	}
	captainAccountID := queuedEntries[0].AccountID
	mapID := s.resolveMapID(queuedEntries[0].PreferredMapPoolID)
	battleID, err := opaqueID("battle")
	if err != nil {
		return err
	}
	assignmentRecord := storage.Assignment{
		AssignmentID:           assignmentID,
		QueueKey:               entry.QueueKey,
		QueueType:              entry.QueueType,
		SeasonID:               entry.SeasonID,
		RoomID:                 roomID,
		RoomKind:               "matchmade_room",
		MatchID:                matchID,
		ModeID:                 entry.ModeID,
		RuleSetID:              entry.RuleSetID,
		MapID:                  mapID,
		ServerHost:             s.defaultDSHost,
		ServerPort:             s.defaultDSPort,
		CaptainAccountID:       captainAccountID,
		AssignmentRevision:     1,
		ExpectedMemberCount:    expectedMemberCount,
		State:                  "assigned",
		CaptainDeadlineUnixSec: now.Add(time.Duration(s.captainDeadlineSeconds) * time.Second).Unix(),
		CommitDeadlineUnixSec:  now.Add(time.Duration(s.commitDeadlineSeconds) * time.Second).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
		// Battle allocation fields.
		SourceRoomID:     "",
		SourceRoomKind:   "",
		BattleID:         battleID,
		AllocationState:  "assigned",
		RoomReturnPolicy: "return_to_source_room",
	}
	if err := assignmentRepo.Insert(ctx, assignmentRecord); err != nil {
		return err
	}
	for idx, queued := range queuedEntries {
		role := "join"
		if queued.AccountID == captainAccountID {
			role = "create"
		}
		member := storage.AssignmentMember{
			AssignmentID:    assignmentID,
			AccountID:       queued.AccountID,
			ProfileID:       queued.ProfileID,
			TicketRole:      role,
			AssignedTeamID:  (idx % 2) + 1,
			RatingBefore:    queued.RatingSnapshot,
			JoinState:       "assigned",
			ResultState:     "",
			CreatedAt:       now,
			UpdatedAt:       now,
			BattleJoinState: "assigned",
			RoomReturnState: "pending",
		}
		if err := assignmentRepo.InsertMember(ctx, member); err != nil {
			return err
		}
		if err := queueRepo.UpdateStatusIfCurrentState(ctx, queued.QueueEntryID, "queued", "assigned", "", assignmentID, 1, now.Unix()); err != nil {
			return err
		}
	}
	return nil
}

func expectedMemberCountFromQueueKey(queueKey string) int {
	const defaultMemberCount = 4
	parts := strings.Split(queueKey, ":")
	if len(parts) < 4 {
		return defaultMemberCount
	}
	formatParts := strings.Split(parts[3], "v")
	if len(formatParts) != 2 {
		return defaultMemberCount
	}
	left, err := strconv.Atoi(formatParts[0])
	if err != nil || left <= 0 {
		return defaultMemberCount
	}
	right, err := strconv.Atoi(formatParts[1])
	if err != nil || right <= 0 {
		return defaultMemberCount
	}
	return left + right
}

func requiredPartySizeFromMatchFormat(matchFormatID string) int {
	switch normalizeMatchFormatID(matchFormatID) {
	case "1v1":
		return 1
	case "2v2":
		return 2
	case "4v4":
		return 4
	default:
		return 0
	}
}

func resolveMatchRoomKind(queueType string) string {
	switch queueType {
	case "ranked":
		return "ranked_match_room"
	default:
		return "casual_match_room"
	}
}

func (s *Service) resolveMapID(preferredMapPoolID string) string {
	if preferredMapPoolID != "" {
		return preferredMapPoolID
	}
	return s.defaultMapID
}

func normalizeModeIDs(modeIDs []string) []string {
	result := make([]string, 0, len(modeIDs))
	seen := map[string]struct{}{}
	for _, modeID := range modeIDs {
		trimmed := strings.TrimSpace(modeID)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	return result
}

func selectCompatibleParties(entries []storage.PartyQueueEntry, requiredPartySize int) []storage.PartyQueueEntry {
	for i, left := range entries {
		if left.PartySize != requiredPartySize {
			continue
		}
		for j, right := range entries {
			if i == j || right.PartySize != requiredPartySize {
				continue
			}
			if firstModeIntersection(left.SelectedModeIDs, right.SelectedModeIDs) == "" {
				continue
			}
			return []storage.PartyQueueEntry{left, right}
		}
	}
	return nil
}

func firstModeIntersection(left []string, right []string) string {
	rightSet := map[string]struct{}{}
	for _, modeID := range right {
		rightSet[modeID] = struct{}{}
	}
	for _, modeID := range left {
		if _, ok := rightSet[modeID]; ok {
			return modeID
		}
	}
	return ""
}

func resolveMapAndRuleForMode(defaultMapID string, modeID string) (string, string) {
	type mapEntry struct {
		mapID     string
		ruleSetID string
	}
	// Catalog of maps per mode — mirrors the Godot MapResource .tres files.
	catalog := map[string][]mapEntry{
		"mode_classic": {
			{mapID: "map_classic_square", ruleSetID: "ruleset_classic"},
		},
		"mode_score_team": {
			{mapID: "map_breakable_center_lane", ruleSetID: "ruleset_score_team"},
		},
	}
	entries, ok := catalog[modeID]
	if !ok || len(entries) == 0 {
		if defaultMapID == "" {
			defaultMapID = "map_classic_square"
		}
		return defaultMapID, "ruleset_classic"
	}
	if len(entries) == 1 {
		return entries[0].mapID, entries[0].ruleSetID
	}
	// Cryptographically seeded random pick among eligible maps.
	var seed [8]byte
	_, _ = rand.Read(seed[:])
	rng := mathrand.New(mathrand.NewSource(int64(binary.LittleEndian.Uint64(seed[:]))))
	picked := entries[rng.Intn(len(entries))]
	return picked.mapID, picked.ruleSetID
}

func (s *Service) resolveRatingSnapshot(ctx context.Context, seasonID string, accountID string) (int, error) {
	if s.ratingRepo == nil {
		return 1000, nil
	}
	snapshot, err := s.ratingRepo.FindSnapshot(ctx, seasonID, accountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return 1000, nil
		}
		return 0, err
	}
	if snapshot.Rating <= 0 {
		return 1000, nil
	}
	return snapshot.Rating, nil
}

func selectRatingCompatibleCandidates(entries []storage.QueueEntry, expectedMemberCount int, nowUnixSec int64) []storage.QueueEntry {
	if len(entries) < expectedMemberCount {
		return nil
	}
	for _, anchor := range entries {
		tolerance := ratingToleranceForWait(nowUnixSec - anchor.EnqueueUnixSec)
		selected := []storage.QueueEntry{anchor}
		for _, candidate := range entries {
			if candidate.QueueEntryID == anchor.QueueEntryID {
				continue
			}
			if absInt(candidate.RatingSnapshot-anchor.RatingSnapshot) > tolerance {
				continue
			}
			selected = append(selected, candidate)
			if len(selected) == expectedMemberCount {
				return selected
			}
		}
	}
	return nil
}

func ratingToleranceForWait(waitSeconds int64) int {
	tolerance := 100 + int(waitSeconds/10)*50
	if tolerance > 600 {
		return 600
	}
	return tolerance
}

func absInt(value int) int {
	if value < 0 {
		return -value
	}
	return value
}

func resolveAssignmentServerEndpoint(assignment storage.Assignment) (string, int) {
	switch normalizeAllocationState(assignment.AllocationState) {
	case "pending_allocate", "allocating", "alloc_failed":
		return "", 0
	}
	if assignment.BattleServerHost != "" && assignment.BattleServerPort > 0 {
		return assignment.BattleServerHost, assignment.BattleServerPort
	}
	return assignment.ServerHost, assignment.ServerPort
}

func resolveAssignmentStatusText(assignment storage.Assignment, defaultText string) string {
	switch normalizeAllocationState(assignment.AllocationState) {
	case "pending_allocate", "allocating":
		return "Battle allocation in progress"
	case "alloc_failed":
		return "Battle allocation failed"
	default:
		return defaultText
	}
}

func normalizeAllocationState(state string) string {
	normalized := strings.TrimSpace(state)
	if normalized == "" {
		return "assigned"
	}
	if normalized == "allocation_failed" {
		return "alloc_failed"
	}
	if normalized == "starting" {
		return "allocated"
	}
	return normalized
}

func deriveAllocationErrorCode(err error) string {
	if err == nil {
		return ""
	}
	message := strings.ToUpper(err.Error())
	switch {
	case strings.Contains(message, "TIMEOUT"):
		return "MATCHMAKING_ALLOCATION_TIMEOUT"
	case strings.Contains(message, "UNAVAILABLE"):
		return "MATCHMAKING_ALLOCATION_UNAVAILABLE"
	case strings.Contains(message, "CONFLICT"):
		return "MATCHMAKING_ALLOCATION_CONFLICT"
	default:
		return "MATCHMAKING_ALLOCATION_FAILED"
	}
}

func normalizeAllocationError(err error) string {
	if err == nil {
		return ""
	}
	message := strings.TrimSpace(err.Error())
	if len(message) > 512 {
		return message[:512]
	}
	return message
}

func (s *Service) reElectCaptainForStatusIfNeeded(ctx context.Context, assignment storage.Assignment, entry storage.QueueEntry, now time.Time) (storage.Assignment, storage.QueueEntry, error) {
	if s.assignmentRepo == nil || assignment.CaptainDeadlineUnixSec >= now.Unix() {
		return assignment, entry, nil
	}
	members, err := s.assignmentRepo.ListMembers(ctx, assignment.AssignmentID)
	if err != nil {
		return storage.Assignment{}, storage.QueueEntry{}, err
	}
	accountIDs := make([]string, 0, len(members))
	for _, member := range members {
		accountIDs = append(accountIDs, member.AccountID)
	}
	nextCaptain := nextCaptainAccountID(assignment.CaptainAccountID, accountIDs)
	if nextCaptain == "" {
		return assignment, entry, nil
	}
	assignment.AssignmentRevision++
	assignment.CaptainAccountID = nextCaptain
	assignment.CaptainDeadlineUnixSec = now.Add(time.Duration(s.captainDeadlineSeconds) * time.Second).Unix()
	if err := s.assignmentRepo.ReelectCaptain(ctx, assignment.AssignmentID, nextCaptain, assignment.AssignmentRevision, assignment.CaptainDeadlineUnixSec); err != nil {
		return storage.Assignment{}, storage.QueueEntry{}, err
	}
	entry.AssignmentRevision = assignment.AssignmentRevision
	return assignment, entry, nil
}

func nextCaptainAccountID(current string, members []string) string {
	if len(members) == 0 {
		return ""
	}
	for idx, member := range members {
		if member == current {
			return members[(idx+1)%len(members)]
		}
	}
	return members[0]
}
