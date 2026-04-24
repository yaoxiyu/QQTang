package assignment

import (
	"context"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"qqtang/services/game_service/internal/storage"
)

type fakeAssignmentRow struct {
	values []any
	err    error
}

func (r fakeAssignmentRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for idx := range dest {
		reflect.ValueOf(dest[idx]).Elem().Set(reflect.ValueOf(r.values[idx]))
	}
	return nil
}

type fakeAssignmentDB struct {
	assignment storage.Assignment
	member     storage.AssignmentMember
}

func (db *fakeAssignmentDB) Exec(_ context.Context, _ string, _ ...any) (pgconn.CommandTag, error) {
	return pgconn.NewCommandTag("UPDATE 1"), nil
}

func (db *fakeAssignmentDB) Query(_ context.Context, _ string, _ ...any) (pgx.Rows, error) {
	return nil, nil
}

func (db *fakeAssignmentDB) QueryRow(_ context.Context, sql string, _ ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "FROM matchmaking_assignments"):
		return fakeAssignmentRow{values: []any{
			db.assignment.AssignmentID,
			db.assignment.QueueKey,
			db.assignment.QueueType,
			db.assignment.SeasonID,
			db.assignment.RoomID,
			db.assignment.RoomKind,
			db.assignment.MatchID,
			db.assignment.ModeID,
			db.assignment.RuleSetID,
			db.assignment.MapID,
			db.assignment.ServerHost,
			db.assignment.ServerPort,
			db.assignment.CaptainAccountID,
			db.assignment.AssignmentRevision,
			db.assignment.ExpectedMemberCount,
			db.assignment.State,
			db.assignment.CaptainDeadlineUnixSec,
			db.assignment.CommitDeadlineUnixSec,
			db.assignment.FinalizedAt,
			db.assignment.CreatedAt,
			db.assignment.UpdatedAt,
			db.assignment.SourceRoomID,
			db.assignment.SourceRoomKind,
			db.assignment.BattleID,
			db.assignment.DSInstanceID,
			db.assignment.BattleServerHost,
			db.assignment.BattleServerPort,
			db.assignment.AllocationState,
			db.assignment.AllocationErrorCode,
			db.assignment.AllocationLastError,
			db.assignment.RoomReturnPolicy,
			db.assignment.AllocationStartedAt,
			db.assignment.BattleReadyAt,
			db.assignment.BattleFinishedAt,
			db.assignment.ReturnCompletedAt,
		}}
	case strings.Contains(sql, "FROM matchmaking_assignment_members"):
		return fakeAssignmentRow{values: []any{
			db.member.AssignmentID,
			db.member.AccountID,
			db.member.ProfileID,
			db.member.TicketRole,
			db.member.AssignedTeamID,
			db.member.RatingBefore,
			db.member.JoinState,
			db.member.ResultState,
			db.member.CreatedAt,
			db.member.UpdatedAt,
			db.member.CharacterID,
			db.member.CharacterSkinID,
			db.member.BubbleStyleID,
			db.member.BubbleSkinID,
			db.member.SourceRoomID,
			db.member.SourceRoomMemberID,
			db.member.BattleJoinState,
			db.member.RoomReturnState,
		}}
	default:
		return fakeAssignmentRow{err: pgx.ErrNoRows}
	}
}

func TestGetGrantRejectsAllocFailedAssignment(t *testing.T) {
	now := time.Now().UTC()
	db := &fakeAssignmentDB{
		assignment: storage.Assignment{
			AssignmentID:          "assign_a",
			QueueType:             "ranked",
			RoomID:                "room_a",
			RoomKind:              "matchmade_room",
			MatchID:               "match_a",
			ModeID:                "mode_a",
			RuleSetID:             "rule_a",
			MapID:                 "map_a",
			CaptainAccountID:      "account_a",
			AssignmentRevision:    1,
			ExpectedMemberCount:   4,
			State:                 "assigned",
			CommitDeadlineUnixSec: now.Add(time.Minute).Unix(),
			AllocationState:       "alloc_failed",
			CreatedAt:             now,
			UpdatedAt:             now,
		},
		member: storage.AssignmentMember{
			AssignmentID: "assign_a",
			AccountID:    "account_a",
			ProfileID:    "profile_a",
			TicketRole:   "create",
			CreatedAt:    now,
			UpdatedAt:    now,
		},
	}
	service := NewService(storage.NewAssignmentRepository(db), time.Minute)
	_, err := service.GetGrant(context.Background(), "assign_a", "account_a", "profile_a", "matchmade_room", "", "room")
	if err != ErrAssignmentAllocFailed {
		t.Fatalf("expected ErrAssignmentAllocFailed, got %v", err)
	}
}

func TestCommitRoomRejectsAllocFailedAssignment(t *testing.T) {
	now := time.Now().UTC()
	db := &fakeAssignmentDB{
		assignment: storage.Assignment{
			AssignmentID:           "assign_b",
			QueueType:              "ranked",
			RoomID:                 "room_b",
			RoomKind:               "matchmade_room",
			MatchID:                "match_b",
			ModeID:                 "mode_b",
			RuleSetID:              "rule_b",
			MapID:                  "map_b",
			CaptainAccountID:       "account_b",
			AssignmentRevision:     2,
			ExpectedMemberCount:    4,
			State:                  "assigned",
			CommitDeadlineUnixSec:  now.Add(time.Minute).Unix(),
			CaptainDeadlineUnixSec: now.Add(time.Minute).Unix(),
			AllocationState:        "alloc_failed",
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		member: storage.AssignmentMember{
			AssignmentID: "assign_b",
			AccountID:    "account_b",
			ProfileID:    "profile_b",
			TicketRole:   "create",
			CreatedAt:    now,
			UpdatedAt:    now,
		},
	}
	service := NewService(storage.NewAssignmentRepository(db), time.Minute)
	_, err := service.CommitRoom(context.Background(), CommitInput{
		AssignmentID:       "assign_b",
		AccountID:          "account_b",
		ProfileID:          "profile_b",
		AssignmentRevision: 2,
		RoomID:             "room_b",
	})
	if err != ErrAssignmentAllocFailed {
		t.Fatalf("expected ErrAssignmentAllocFailed, got %v", err)
	}
}
