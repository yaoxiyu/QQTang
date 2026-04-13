package queue

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"qqtang/services/game_service/internal/storage"
)

var (
	ErrQueueAlreadyActive      = errors.New("MATCHMAKING_QUEUE_ALREADY_ACTIVE")
	ErrQueueNotFound           = errors.New("MATCHMAKING_QUEUE_NOT_FOUND")
	ErrQueueTypeInvalid        = errors.New("MATCHMAKING_QUEUE_TYPE_INVALID")
	ErrModeInvalid             = errors.New("MATCHMAKING_MODE_INVALID")
	ErrRuleSetInvalid          = errors.New("MATCHMAKING_RULE_SET_INVALID")
	ErrAssignmentExpired       = errors.New("MATCHMAKING_ASSIGNMENT_EXPIRED")
	ErrAssignmentRevisionStale = errors.New("MATCHMAKING_ASSIGNMENT_REVISION_STALE")
)

type Service struct {
	queueRepo      *storage.QueueRepository
	assignmentRepo *storage.AssignmentRepository
	heartbeatTTL   time.Duration
}

func NewService(queueRepo *storage.QueueRepository, assignmentRepo *storage.AssignmentRepository, heartbeatTTL time.Duration) *Service {
	return &Service{
		queueRepo:      queueRepo,
		assignmentRepo: assignmentRepo,
		heartbeatTTL:   heartbeatTTL,
	}
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
	entryID, err := opaqueID("queue")
	if err != nil {
		return QueueStatus{}, err
	}
	entry := storage.QueueEntry{
		QueueEntryID:         entryID,
		QueueType:            input.QueueType,
		QueueKey:             BuildQueueKey(input.QueueType, input.ModeID, input.RuleSetID),
		SeasonID:             "season_s1",
		AccountID:            input.AccountID,
		ProfileID:            input.ProfileID,
		DeviceSessionID:      input.DeviceSessionID,
		ModeID:               input.ModeID,
		RuleSetID:            input.RuleSetID,
		PreferredMapPoolID:   input.PreferredMapPoolID,
		RatingSnapshot:       1000,
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
	return s.buildQueuedStatus(entry), nil
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
	member, err := s.assignmentRepo.FindMember(ctx, entry.AssignmentID, entry.AccountID)
	if err != nil {
		return QueueStatus{}, err
	}
	if assignment.AssignmentRevision != entry.AssignmentRevision {
		return QueueStatus{}, ErrAssignmentRevisionStale
	}
	if assignment.CommitDeadlineUnixSec < now.Unix() {
		return QueueStatus{}, ErrAssignmentExpired
	}
	_ = s.queueRepo.UpdateStatus(ctx, entry.QueueEntryID, entry.State, entry.CancelReason, entry.AssignmentID, entry.AssignmentRevision, now.Unix())
	return QueueStatus{
		QueueState:             entry.State,
		QueueEntryID:           entry.QueueEntryID,
		QueueKey:               entry.QueueKey,
		AssignmentID:           assignment.AssignmentID,
		AssignmentRevision:     assignment.AssignmentRevision,
		QueueStatusText:        "Match found",
		AssignmentStatusText:   "Waiting for ticket request",
		EnqueueUnixSec:         entry.EnqueueUnixSec,
		LastHeartbeatUnixSec:   now.Unix(),
		ExpiresAtUnixSec:       now.Unix() + int64(s.heartbeatTTL.Seconds()),
		TicketRole:             member.TicketRole,
		RoomID:                 assignment.RoomID,
		RoomKind:               assignment.RoomKind,
		ServerHost:             assignment.ServerHost,
		ServerPort:             assignment.ServerPort,
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

func opaqueID(prefix string) (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return prefix + "_" + hex.EncodeToString(buf), nil
}
