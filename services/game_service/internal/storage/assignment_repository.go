package storage

import (
	"context"
	"time"
)

type Assignment struct {
	AssignmentID           string
	QueueKey               string
	QueueType              string
	SeasonID               string
	RoomID                 string
	RoomKind               string
	MatchID                string
	ModeID                 string
	RuleSetID              string
	MapID                  string
	ServerHost             string
	ServerPort             int
	CaptainAccountID       string
	AssignmentRevision     int
	ExpectedMemberCount    int
	State                  string
	CaptainDeadlineUnixSec int64
	CommitDeadlineUnixSec  int64
	FinalizedAt            *time.Time
	CreatedAt              time.Time
	UpdatedAt              time.Time
}

type AssignmentMember struct {
	AssignmentID   string
	AccountID      string
	ProfileID      string
	TicketRole     string
	AssignedTeamID int
	RatingBefore   int
	JoinState      string
	ResultState    string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type AssignmentRepository struct {
	db DBTX
}

func NewAssignmentRepository(db DBTX) *AssignmentRepository {
	return &AssignmentRepository{db: db}
}

func (r *AssignmentRepository) FindByID(ctx context.Context, assignmentID string) (Assignment, error) {
	var record Assignment
	var finalizedAt *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT assignment_id, queue_key, queue_type, season_id, room_id, room_kind, match_id, mode_id, rule_set_id,
		       map_id, server_host, server_port, captain_account_id, assignment_revision, expected_member_count,
		       state, captain_deadline_unix_sec, commit_deadline_unix_sec, finalized_at, created_at, updated_at
		FROM matchmaking_assignments
		WHERE assignment_id = $1
	`, assignmentID).Scan(
		&record.AssignmentID, &record.QueueKey, &record.QueueType, &record.SeasonID, &record.RoomID, &record.RoomKind,
		&record.MatchID, &record.ModeID, &record.RuleSetID, &record.MapID, &record.ServerHost, &record.ServerPort,
		&record.CaptainAccountID, &record.AssignmentRevision, &record.ExpectedMemberCount, &record.State,
		&record.CaptainDeadlineUnixSec, &record.CommitDeadlineUnixSec, &finalizedAt, &record.CreatedAt, &record.UpdatedAt,
	)
	if err != nil {
		return Assignment{}, mapNotFound(err)
	}
	record.FinalizedAt = finalizedAt
	return record, nil
}

func (r *AssignmentRepository) FindMember(ctx context.Context, assignmentID string, accountID string) (AssignmentMember, error) {
	var record AssignmentMember
	err := r.db.QueryRow(ctx, `
		SELECT assignment_id, account_id, profile_id, ticket_role, assigned_team_id, rating_before, join_state, result_state, created_at, updated_at
		FROM matchmaking_assignment_members
		WHERE assignment_id = $1 AND account_id = $2
	`, assignmentID, accountID).Scan(
		&record.AssignmentID, &record.AccountID, &record.ProfileID, &record.TicketRole, &record.AssignedTeamID,
		&record.RatingBefore, &record.JoinState, &record.ResultState, &record.CreatedAt, &record.UpdatedAt,
	)
	if err != nil {
		return AssignmentMember{}, mapNotFound(err)
	}
	return record, nil
}

func (r *AssignmentRepository) MarkFinalized(ctx context.Context, assignmentID string, finalizedAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignments
		SET state = 'finalized',
		    finalized_at = $2,
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID, finalizedAt)
	return err
}
