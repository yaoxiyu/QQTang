package assignment

import (
	"context"
	"errors"
	"time"

	"qqtang/services/game_service/internal/storage"
)

var (
	ErrAssignmentNotFound       = errors.New("MATCHMAKING_ASSIGNMENT_NOT_FOUND")
	ErrAssignmentMemberNotFound = errors.New("MATCHMAKING_ASSIGNMENT_MEMBER_NOT_FOUND")
	ErrAssignmentExpired        = errors.New("MATCHMAKING_ASSIGNMENT_EXPIRED")
	ErrAssignmentGrantForbidden = errors.New("MATCHMAKING_ASSIGNMENT_GRANT_FORBIDDEN")
)

type Service struct {
	repo *storage.AssignmentRepository
}

func NewService(repo *storage.AssignmentRepository, _ time.Duration) *Service {
	return &Service{repo: repo}
}

func (s *Service) GetGrant(ctx context.Context, assignmentID string, accountID string, profileID string, roomKind string) (GrantResult, error) {
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
	if roomKind != "" && roomKind != assignmentRecord.RoomKind {
		return GrantResult{}, ErrAssignmentGrantForbidden
	}
	if assignmentRecord.CommitDeadlineUnixSec < time.Now().UTC().Unix() || assignmentRecord.State == "finalized" {
		return GrantResult{}, ErrAssignmentExpired
	}
	return GrantResult{
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
	}, nil
}
