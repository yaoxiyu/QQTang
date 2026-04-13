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
	queueRepo              *storage.QueueRepository
	assignmentRepo         *storage.AssignmentRepository
	ratingRepo             *storage.RatingRepository
	heartbeatTTL           time.Duration
	defaultDSHost          string
	defaultDSPort          int
	captainDeadlineSeconds int
	commitDeadlineSeconds  int
}

func NewService(queueRepo *storage.QueueRepository, assignmentRepo *storage.AssignmentRepository, heartbeatTTL time.Duration) *Service {
	return &Service{
		queueRepo:              queueRepo,
		assignmentRepo:         assignmentRepo,
		heartbeatTTL:           heartbeatTTL,
		defaultDSHost:          "127.0.0.1",
		defaultDSPort:          9000,
		captainDeadlineSeconds: 15,
		commitDeadlineSeconds:  45,
	}
}

func (s *Service) ConfigureAssignmentDefaults(defaultDSHost string, defaultDSPort int, captainDeadlineSeconds int, commitDeadlineSeconds int) {
	if defaultDSHost != "" {
		s.defaultDSHost = defaultDSHost
	}
	if defaultDSPort > 0 {
		s.defaultDSPort = defaultDSPort
	}
	if captainDeadlineSeconds > 0 {
		s.captainDeadlineSeconds = captainDeadlineSeconds
	}
	if commitDeadlineSeconds > 0 {
		s.commitDeadlineSeconds = commitDeadlineSeconds
	}
}

func (s *Service) ConfigureRatingRepository(ratingRepo *storage.RatingRepository) {
	s.ratingRepo = ratingRepo
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
	seasonID := "season_s1"
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
		QueueKey:             BuildQueueKey(input.QueueType, input.ModeID, input.RuleSetID),
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

func (s *Service) tryFormAssignment(ctx context.Context, entry storage.QueueEntry) error {
	const expectedMemberCount = 4
	const candidateLimit = 32
	if s.assignmentRepo == nil {
		return nil
	}
	now := time.Now().UTC()
	minHeartbeatUnixSec := now.Add(-s.heartbeatTTL).Unix()
	queuedEntries, err := s.queueRepo.FindQueuedByKey(ctx, entry.QueueKey, candidateLimit, minHeartbeatUnixSec)
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
	mapID := resolveMapID(queuedEntries[0].PreferredMapPoolID)
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
	}
	if err := s.assignmentRepo.Insert(ctx, assignmentRecord); err != nil {
		return err
	}
	for idx, queued := range queuedEntries {
		role := "join"
		if queued.AccountID == captainAccountID {
			role = "create"
		}
		member := storage.AssignmentMember{
			AssignmentID:   assignmentID,
			AccountID:      queued.AccountID,
			ProfileID:      queued.ProfileID,
			TicketRole:     role,
			AssignedTeamID: (idx % 2) + 1,
			RatingBefore:   queued.RatingSnapshot,
			JoinState:      "assigned",
			ResultState:    "",
			CreatedAt:      now,
			UpdatedAt:      now,
		}
		if err := s.assignmentRepo.InsertMember(ctx, member); err != nil {
			return err
		}
		if err := s.queueRepo.UpdateStatus(ctx, queued.QueueEntryID, "assigned", "", assignmentID, 1, now.Unix()); err != nil {
			return err
		}
	}
	return nil
}

func resolveMapID(preferredMapPoolID string) string {
	if preferredMapPoolID != "" {
		return preferredMapPoolID
	}
	return "map_classic_square"
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
