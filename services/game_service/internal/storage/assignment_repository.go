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

	// Phase23: Room/Battle decoupling fields
	SourceRoomID       string
	SourceRoomKind     string
	BattleID           string
	DSInstanceID       string
	BattleServerHost   string
	BattleServerPort   int
	AllocationState    string
	RoomReturnPolicy   string
	AllocationStartedAt *time.Time
	BattleReadyAt      *time.Time
	BattleFinishedAt   *time.Time
	ReturnCompletedAt  *time.Time
}

type AssignmentMember struct {
	AssignmentID       string
	AccountID          string
	ProfileID          string
	TicketRole         string
	AssignedTeamID     int
	RatingBefore       int
	JoinState          string
	ResultState        string
	CreatedAt          time.Time
	UpdatedAt          time.Time

	// Phase23: Room/Battle decoupling fields
	SourceRoomID       string
	SourceRoomMemberID string
	BattleJoinState    string
	RoomReturnState    string
}

type AssignmentRepository struct {
	db DBTX
}

func NewAssignmentRepository(db DBTX) *AssignmentRepository {
	return &AssignmentRepository{db: db}
}

func (r *AssignmentRepository) Insert(ctx context.Context, assignment Assignment) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO matchmaking_assignments (
			assignment_id, queue_key, queue_type, season_id, room_id, room_kind, match_id,
			mode_id, rule_set_id, map_id, server_host, server_port, captain_account_id,
			assignment_revision, expected_member_count, state, captain_deadline_unix_sec,
			commit_deadline_unix_sec, created_at, updated_at,
			source_room_id, source_room_kind, battle_id, ds_instance_id,
			battle_server_host, battle_server_port, allocation_state, room_return_policy,
			allocation_started_at, battle_ready_at, battle_finished_at, return_completed_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
			$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32
		)
	`, assignment.AssignmentID, assignment.QueueKey, assignment.QueueType, assignment.SeasonID, assignment.RoomID,
		assignment.RoomKind, assignment.MatchID, assignment.ModeID, assignment.RuleSetID, assignment.MapID,
		assignment.ServerHost, assignment.ServerPort, assignment.CaptainAccountID, assignment.AssignmentRevision,
		assignment.ExpectedMemberCount, assignment.State, assignment.CaptainDeadlineUnixSec,
		assignment.CommitDeadlineUnixSec, assignment.CreatedAt, assignment.UpdatedAt,
		assignment.SourceRoomID, assignment.SourceRoomKind, assignment.BattleID, assignment.DSInstanceID,
		assignment.BattleServerHost, assignment.BattleServerPort, assignment.AllocationState, assignment.RoomReturnPolicy,
		assignment.AllocationStartedAt, assignment.BattleReadyAt, assignment.BattleFinishedAt, assignment.ReturnCompletedAt)
	return err
}

func (r *AssignmentRepository) InsertMember(ctx context.Context, member AssignmentMember) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO matchmaking_assignment_members (
			assignment_id, account_id, profile_id, ticket_role, assigned_team_id,
			rating_before, join_state, result_state, created_at, updated_at,
			source_room_id, source_room_member_id, battle_join_state, room_return_state
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14
		)
	`, member.AssignmentID, member.AccountID, member.ProfileID, member.TicketRole, member.AssignedTeamID,
		member.RatingBefore, member.JoinState, member.ResultState, member.CreatedAt, member.UpdatedAt,
		member.SourceRoomID, member.SourceRoomMemberID, member.BattleJoinState, member.RoomReturnState)
	return err
}

func (r *AssignmentRepository) FindByID(ctx context.Context, assignmentID string) (Assignment, error) {
	var record Assignment
	var finalizedAt *time.Time
	var allocationStartedAt, battleReadyAt, battleFinishedAt, returnCompletedAt *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT assignment_id, queue_key, queue_type, season_id, room_id, room_kind, match_id, mode_id, rule_set_id,
		       map_id, server_host, server_port, captain_account_id, assignment_revision, expected_member_count,
		       state, captain_deadline_unix_sec, commit_deadline_unix_sec, finalized_at, created_at, updated_at,
		       source_room_id, source_room_kind, battle_id, ds_instance_id,
		       battle_server_host, battle_server_port, allocation_state, room_return_policy,
		       allocation_started_at, battle_ready_at, battle_finished_at, return_completed_at
		FROM matchmaking_assignments
		WHERE assignment_id = $1
	`, assignmentID).Scan(
		&record.AssignmentID, &record.QueueKey, &record.QueueType, &record.SeasonID, &record.RoomID, &record.RoomKind,
		&record.MatchID, &record.ModeID, &record.RuleSetID, &record.MapID, &record.ServerHost, &record.ServerPort,
		&record.CaptainAccountID, &record.AssignmentRevision, &record.ExpectedMemberCount, &record.State,
		&record.CaptainDeadlineUnixSec, &record.CommitDeadlineUnixSec, &finalizedAt, &record.CreatedAt, &record.UpdatedAt,
		&record.SourceRoomID, &record.SourceRoomKind, &record.BattleID, &record.DSInstanceID,
		&record.BattleServerHost, &record.BattleServerPort, &record.AllocationState, &record.RoomReturnPolicy,
		&allocationStartedAt, &battleReadyAt, &battleFinishedAt, &returnCompletedAt,
	)
	if err != nil {
		return Assignment{}, mapNotFound(err)
	}
	record.FinalizedAt = finalizedAt
	record.AllocationStartedAt = allocationStartedAt
	record.BattleReadyAt = battleReadyAt
	record.BattleFinishedAt = battleFinishedAt
	record.ReturnCompletedAt = returnCompletedAt
	return record, nil
}

func (r *AssignmentRepository) FindMember(ctx context.Context, assignmentID string, accountID string) (AssignmentMember, error) {
	var record AssignmentMember
	err := r.db.QueryRow(ctx, `
		SELECT assignment_id, account_id, profile_id, ticket_role, assigned_team_id, rating_before, join_state, result_state, created_at, updated_at,
		       source_room_id, source_room_member_id, battle_join_state, room_return_state
		FROM matchmaking_assignment_members
		WHERE assignment_id = $1 AND account_id = $2
	`, assignmentID, accountID).Scan(
		&record.AssignmentID, &record.AccountID, &record.ProfileID, &record.TicketRole, &record.AssignedTeamID,
		&record.RatingBefore, &record.JoinState, &record.ResultState, &record.CreatedAt, &record.UpdatedAt,
		&record.SourceRoomID, &record.SourceRoomMemberID, &record.BattleJoinState, &record.RoomReturnState,
	)
	if err != nil {
		return AssignmentMember{}, mapNotFound(err)
	}
	return record, nil
}

func (r *AssignmentRepository) ListMembers(ctx context.Context, assignmentID string) ([]AssignmentMember, error) {
	rows, err := r.db.Query(ctx, `
		SELECT assignment_id, account_id, profile_id, ticket_role, assigned_team_id, rating_before, join_state, result_state, created_at, updated_at,
		       source_room_id, source_room_member_id, battle_join_state, room_return_state
		FROM matchmaking_assignment_members
		WHERE assignment_id = $1
		ORDER BY created_at ASC, account_id ASC
	`, assignmentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	members := []AssignmentMember{}
	for rows.Next() {
		var record AssignmentMember
		if err := rows.Scan(
			&record.AssignmentID, &record.AccountID, &record.ProfileID, &record.TicketRole, &record.AssignedTeamID,
			&record.RatingBefore, &record.JoinState, &record.ResultState, &record.CreatedAt, &record.UpdatedAt,
			&record.SourceRoomID, &record.SourceRoomMemberID, &record.BattleJoinState, &record.RoomReturnState,
		); err != nil {
			return nil, err
		}
		members = append(members, record)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return members, nil
}

func (r *AssignmentRepository) ReelectCaptain(ctx context.Context, assignmentID string, captainAccountID string, revision int, captainDeadlineUnixSec int64) error {
	if _, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignments
		SET captain_account_id = $2,
		    assignment_revision = $3,
		    captain_deadline_unix_sec = $4,
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID, captainAccountID, revision, captainDeadlineUnixSec); err != nil {
		return err
	}
	if _, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignment_members
		SET ticket_role = CASE WHEN account_id = $2 THEN 'create' ELSE 'join' END,
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID, captainAccountID); err != nil {
		return err
	}
	if _, err := r.db.Exec(ctx, `
		UPDATE matchmaking_queue_entries
		SET assignment_revision = $2,
		    updated_at = NOW()
		WHERE assignment_id = $1
		  AND state IN ('assigned', 'committing')
	`, assignmentID, revision); err != nil {
		return err
	}
	return nil
}

func (r *AssignmentRepository) MarkMemberTicketGranted(ctx context.Context, assignmentID string, accountID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignment_members
		SET join_state = 'ticket_granted',
		    updated_at = NOW()
		WHERE assignment_id = $1
		  AND account_id = $2
	`, assignmentID, accountID)
	return err
}

func (r *AssignmentRepository) MarkCommitted(ctx context.Context, assignmentID string, accountID string) error {
	if _, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignments
		SET state = 'committed',
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID); err != nil {
		return err
	}
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignment_members
		SET join_state = 'room_committed',
		    updated_at = NOW()
		WHERE assignment_id = $1
		  AND account_id = $2
	`, assignmentID, accountID)
	return err
}

func (r *AssignmentRepository) MarkMembersFinalized(ctx context.Context, assignmentID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignment_members
		SET result_state = 'finalized',
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID)
	return err
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

// Phase23: Update allocation state and battle DS connection info
func (r *AssignmentRepository) UpdateAllocationState(ctx context.Context, assignmentID string, allocationState string, battleID string, dsInstanceID string, battleServerHost string, battleServerPort int) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_assignments
		SET allocation_state = $2,
		    battle_id = $3,
		    ds_instance_id = $4,
		    battle_server_host = $5,
		    battle_server_port = $6,
		    allocation_started_at = CASE WHEN $2 = 'allocating' THEN NOW() ELSE allocation_started_at END,
		    battle_ready_at = CASE WHEN $2 = 'battle_ready' THEN NOW() ELSE battle_ready_at END,
		    battle_finished_at = CASE WHEN $2 = 'battle_finished' THEN NOW() ELSE battle_finished_at END,
		    updated_at = NOW()
		WHERE assignment_id = $1
	`, assignmentID, allocationState, battleID, dsInstanceID, battleServerHost, battleServerPort)
	return err
}

func (r *AssignmentRepository) FindByBattleID(ctx context.Context, battleID string) (Assignment, error) {
	var record Assignment
	var finalizedAt *time.Time
	var allocationStartedAt, battleReadyAt, battleFinishedAt, returnCompletedAt *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT assignment_id, queue_key, queue_type, season_id, room_id, room_kind, match_id, mode_id, rule_set_id,
		       map_id, server_host, server_port, captain_account_id, assignment_revision, expected_member_count,
		       state, captain_deadline_unix_sec, commit_deadline_unix_sec, finalized_at, created_at, updated_at,
		       source_room_id, source_room_kind, battle_id, ds_instance_id,
		       battle_server_host, battle_server_port, allocation_state, room_return_policy,
		       allocation_started_at, battle_ready_at, battle_finished_at, return_completed_at
		FROM matchmaking_assignments
		WHERE battle_id = $1
	`, battleID).Scan(
		&record.AssignmentID, &record.QueueKey, &record.QueueType, &record.SeasonID, &record.RoomID, &record.RoomKind,
		&record.MatchID, &record.ModeID, &record.RuleSetID, &record.MapID, &record.ServerHost, &record.ServerPort,
		&record.CaptainAccountID, &record.AssignmentRevision, &record.ExpectedMemberCount, &record.State,
		&record.CaptainDeadlineUnixSec, &record.CommitDeadlineUnixSec, &finalizedAt, &record.CreatedAt, &record.UpdatedAt,
		&record.SourceRoomID, &record.SourceRoomKind, &record.BattleID, &record.DSInstanceID,
		&record.BattleServerHost, &record.BattleServerPort, &record.AllocationState, &record.RoomReturnPolicy,
		&allocationStartedAt, &battleReadyAt, &battleFinishedAt, &returnCompletedAt,
	)
	if err != nil {
		return Assignment{}, mapNotFound(err)
	}
	record.FinalizedAt = finalizedAt
	record.AllocationStartedAt = allocationStartedAt
	record.BattleReadyAt = battleReadyAt
	record.BattleFinishedAt = battleFinishedAt
	record.ReturnCompletedAt = returnCompletedAt
	return record, nil
}
