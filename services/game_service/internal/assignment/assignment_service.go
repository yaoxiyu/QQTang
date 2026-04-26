package assignment

import (
	"context"
	"errors"
	"strings"
	"time"

	"qqtang/services/game_service/internal/storage"
)

var (
	ErrAssignmentNotFound       = errors.New("MATCHMAKING_ASSIGNMENT_NOT_FOUND")
	ErrAssignmentMemberNotFound = errors.New("MATCHMAKING_ASSIGNMENT_MEMBER_NOT_FOUND")
	ErrAssignmentExpired        = errors.New("MATCHMAKING_ASSIGNMENT_EXPIRED")
	ErrAssignmentAllocFailed    = errors.New("MATCHMAKING_ASSIGNMENT_ALLOC_FAILED")
	ErrAssignmentGrantForbidden = errors.New("MATCHMAKING_ASSIGNMENT_GRANT_FORBIDDEN")
	ErrAssignmentRevisionStale  = errors.New("MATCHMAKING_ASSIGNMENT_REVISION_STALE")
)

type Service struct {
	repo            *storage.AssignmentRepository
	captainDeadline time.Duration
}

func NewService(repo *storage.AssignmentRepository, captainDeadline time.Duration) *Service {
	return &Service{repo: repo, captainDeadline: captainDeadline}
}

func (s *Service) GetGrant(ctx context.Context, assignmentID string, accountID string, profileID string, roomKind string, battleID string, ticketType string) (GrantResult, error) {
	assignmentRecord, err := s.repo.FindByID(ctx, assignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return GrantResult{}, ErrAssignmentNotFound
		}
		return GrantResult{}, err
	}
	member, err := s.repo.FindMember(ctx, assignmentID, accountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return GrantResult{}, ErrAssignmentMemberNotFound
		}
		return GrantResult{}, err
	}
	if member.ProfileID != profileID {
		return GrantResult{}, ErrAssignmentGrantForbidden
	}
	isBattleTicket := strings.EqualFold(strings.TrimSpace(ticketType), "battle")
	if isBattleTicket {
		if battleID == "" || assignmentRecord.BattleID != battleID {
			return GrantResult{}, ErrAssignmentGrantForbidden
		}
	} else if roomKind != "" && roomKind != assignmentRecord.RoomKind {
		return GrantResult{}, ErrAssignmentGrantForbidden
	}
	if assignmentRecord.CommitDeadlineUnixSec < time.Now().UTC().Unix() || assignmentRecord.State == "finalized" {
		return GrantResult{}, ErrAssignmentExpired
	}
	if assignmentRecord.AllocationState == "alloc_failed" || assignmentRecord.AllocationState == "allocation_failed" {
		return GrantResult{}, ErrAssignmentAllocFailed
	}
	assignmentRecord, member, err = s.reElectCaptainIfNeeded(ctx, assignmentRecord, member)
	if err != nil {
		return GrantResult{}, err
	}
	if err := s.repo.MarkMemberTicketGranted(ctx, assignmentRecord.AssignmentID, member.AccountID); err != nil {
		return GrantResult{}, err
	}
	result := GrantResult{
		AssignmentID:           assignmentRecord.AssignmentID,
		AssignmentRevision:     assignmentRecord.AssignmentRevision,
		GrantState:             "grantable",
		MatchSource:            "matchmaking",
		QueueType:              assignmentRecord.QueueType,
		TicketRole:             member.TicketRole,
		RoomID:                 assignmentRecord.RoomID,
		RoomKind:               assignmentRecord.RoomKind,
		MatchID:                assignmentRecord.MatchID,
		SeasonID:               assignmentRecord.SeasonID,
		ServerHost:             assignmentRecord.ServerHost,
		ServerPort:             assignmentRecord.ServerPort,
		LockedMapID:            assignmentRecord.MapID,
		LockedRuleSetID:        assignmentRecord.RuleSetID,
		LockedModeID:           assignmentRecord.ModeID,
		AssignedTeamID:         member.AssignedTeamID,
		ExpectedMemberCount:    assignmentRecord.ExpectedMemberCount,
		AutoReadyOnJoin:        true,
		HiddenRoom:             true,
		CaptainAccountID:       assignmentRecord.CaptainAccountID,
		CaptainDeadlineUnixSec: assignmentRecord.CaptainDeadlineUnixSec,
		CommitDeadlineUnixSec:  assignmentRecord.CommitDeadlineUnixSec,
		BattleID:               assignmentRecord.BattleID,
		BattleServerHost:       assignmentRecord.BattleServerHost,
		BattleServerPort:       assignmentRecord.BattleServerPort,
		AllocationState:        assignmentRecord.AllocationState,
	}
	if isBattleTicket {
		result.RoomID = ""
		result.RoomKind = ""
		result.ServerHost = ""
		result.ServerPort = 0
		result.HiddenRoom = false
	}
	return result, nil
}

func (s *Service) CommitRoom(ctx context.Context, input CommitInput) (CommitResult, error) {
	assignmentRecord, err := s.repo.FindByID(ctx, input.AssignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return CommitResult{}, ErrAssignmentNotFound
		}
		return CommitResult{}, err
	}
	member, err := s.repo.FindMember(ctx, input.AssignmentID, input.AccountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return CommitResult{}, ErrAssignmentMemberNotFound
		}
		return CommitResult{}, err
	}
	if member.ProfileID != input.ProfileID || member.TicketRole != "create" || assignmentRecord.CaptainAccountID != input.AccountID {
		return CommitResult{}, ErrAssignmentGrantForbidden
	}
	if input.AssignmentRevision != assignmentRecord.AssignmentRevision {
		return CommitResult{}, ErrAssignmentRevisionStale
	}
	if input.RoomID != "" && input.RoomID != assignmentRecord.RoomID {
		return CommitResult{}, ErrAssignmentGrantForbidden
	}
	now := time.Now().UTC().Unix()
	if assignmentRecord.CommitDeadlineUnixSec < now || assignmentRecord.State == "finalized" {
		return CommitResult{}, ErrAssignmentExpired
	}
	if assignmentRecord.AllocationState == "alloc_failed" || assignmentRecord.AllocationState == "allocation_failed" {
		return CommitResult{}, ErrAssignmentAllocFailed
	}
	if assignmentRecord.State != "committed" {
		if err := s.repo.MarkCommitted(ctx, assignmentRecord.AssignmentID, input.AccountID); err != nil {
			return CommitResult{}, err
		}
	}
	return CommitResult{
		AssignmentID:       assignmentRecord.AssignmentID,
		AssignmentRevision: assignmentRecord.AssignmentRevision,
		CommitState:        "committed",
		RoomID:             assignmentRecord.RoomID,
	}, nil
}

func (s *Service) CommitBattleEntryReady(ctx context.Context, input CommitInput) (CommitResult, error) {
	assignmentRecord, err := s.repo.FindByID(ctx, input.AssignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return CommitResult{}, ErrAssignmentNotFound
		}
		return CommitResult{}, err
	}
	member, err := s.repo.FindMember(ctx, input.AssignmentID, input.AccountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return CommitResult{}, ErrAssignmentMemberNotFound
		}
		return CommitResult{}, err
	}
	if member.ProfileID != input.ProfileID {
		return CommitResult{}, ErrAssignmentGrantForbidden
	}
	if input.AssignmentRevision != assignmentRecord.AssignmentRevision {
		return CommitResult{}, ErrAssignmentRevisionStale
	}
	if assignmentRecord.BattleID == "" || input.BattleID == "" || input.BattleID != assignmentRecord.BattleID {
		return CommitResult{}, ErrAssignmentGrantForbidden
	}
	now := time.Now().UTC().Unix()
	if assignmentRecord.CommitDeadlineUnixSec < now || assignmentRecord.State == "finalized" {
		return CommitResult{}, ErrAssignmentExpired
	}
	if assignmentRecord.AllocationState == "alloc_failed" || assignmentRecord.AllocationState == "allocation_failed" {
		return CommitResult{}, ErrAssignmentAllocFailed
	}
	if err := s.repo.MarkCommitted(ctx, assignmentRecord.AssignmentID, input.AccountID); err != nil {
		return CommitResult{}, err
	}
	return CommitResult{
		AssignmentID:       assignmentRecord.AssignmentID,
		AssignmentRevision: assignmentRecord.AssignmentRevision,
		CommitState:        "committed",
		RoomID:             assignmentRecord.RoomID,
	}, nil
}

func (s *Service) GetStatus(ctx context.Context, roomID string, assignmentID string) (StatusResult, error) {
	assignmentRecord, err := s.repo.FindByID(ctx, assignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return StatusResult{}, ErrAssignmentNotFound
		}
		return StatusResult{}, err
	}
	if roomID != "" && assignmentRecord.RoomID != roomID {
		return StatusResult{}, ErrAssignmentGrantForbidden
	}
	queueState := "battle_ready"
	queuePhase := "entry_ready"
	queueTerminalReason := "none"
	queueStatusText := "battle_ready"
	if assignmentRecord.State == "finalized" {
		queueState = "finalized"
		queuePhase = "completed"
		queueTerminalReason = "match_finalized"
		queueStatusText = "Match finalized"
	} else if assignmentRecord.AllocationState == "alloc_failed" || assignmentRecord.AllocationState == "allocation_failed" {
		queueState = "failed"
		queuePhase = "completed"
		queueTerminalReason = "allocation_failed"
		queueStatusText = "Battle allocation failed"
	}
	return StatusResult{
		AssignmentID:        assignmentRecord.AssignmentID,
		AssignmentRevision:  assignmentRecord.AssignmentRevision,
		RoomID:              assignmentRecord.RoomID,
		RoomKind:            assignmentRecord.RoomKind,
		MatchID:             assignmentRecord.MatchID,
		BattleID:            assignmentRecord.BattleID,
		ServerHost:          assignmentRecord.BattleServerHost,
		ServerPort:          assignmentRecord.BattleServerPort,
		QueueState:          queueState,
		QueuePhase:          queuePhase,
		QueueTerminalReason: queueTerminalReason,
		QueueStatusText:     queueStatusText,
		AllocationState:     assignmentRecord.AllocationState,
	}, nil
}

func (s *Service) reElectCaptainIfNeeded(ctx context.Context, assignmentRecord storage.Assignment, member storage.AssignmentMember) (storage.Assignment, storage.AssignmentMember, error) {
	now := time.Now().UTC()
	if assignmentRecord.State == "committed" || assignmentRecord.CaptainDeadlineUnixSec >= now.Unix() {
		return assignmentRecord, member, nil
	}
	members, err := s.repo.ListMembers(ctx, assignmentRecord.AssignmentID)
	if err != nil {
		return storage.Assignment{}, storage.AssignmentMember{}, err
	}
	accountIDs := make([]string, 0, len(members))
	for _, candidate := range members {
		accountIDs = append(accountIDs, candidate.AccountID)
	}
	nextCaptain := NextCaptainAccountID(assignmentRecord.CaptainAccountID, accountIDs)
	if nextCaptain == "" {
		return assignmentRecord, member, nil
	}
	nextRevision := assignmentRecord.AssignmentRevision + 1
	nextDeadline := now.Add(s.captainDeadline).Unix()
	if err := s.repo.ReelectCaptain(ctx, assignmentRecord.AssignmentID, nextCaptain, nextRevision, nextDeadline); err != nil {
		return storage.Assignment{}, storage.AssignmentMember{}, err
	}
	assignmentRecord.CaptainAccountID = nextCaptain
	assignmentRecord.AssignmentRevision = nextRevision
	assignmentRecord.CaptainDeadlineUnixSec = nextDeadline
	member, err = s.repo.FindMember(ctx, assignmentRecord.AssignmentID, member.AccountID)
	if err != nil {
		return storage.Assignment{}, storage.AssignmentMember{}, err
	}
	return assignmentRecord, member, nil
}
