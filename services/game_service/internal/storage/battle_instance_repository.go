package storage

import (
	"context"
	"time"
)

type BattleInstance struct {
	BattleID     string
	AssignmentID string
	MatchID      string
	DSInstanceID string
	ServerHost   string
	ServerPort   int
	State        string
	StartedAt    *time.Time
	ReadyAt      *time.Time
	FinishedAt   *time.Time
	FinalizedAt  *time.Time
	ReapedAt     *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type BattleInstanceRepository struct {
	db DBTX
}

func NewBattleInstanceRepository(db DBTX) *BattleInstanceRepository {
	return &BattleInstanceRepository{db: db}
}

func (r *BattleInstanceRepository) Insert(ctx context.Context, bi BattleInstance) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO battle_instances (
			battle_id, assignment_id, match_id, ds_instance_id,
			server_host, server_port, state,
			started_at, ready_at, finished_at, finalized_at, reaped_at,
			created_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14
		)
	`, bi.BattleID, bi.AssignmentID, bi.MatchID, bi.DSInstanceID,
		bi.ServerHost, bi.ServerPort, bi.State,
		bi.StartedAt, bi.ReadyAt, bi.FinishedAt, bi.FinalizedAt, bi.ReapedAt,
		bi.CreatedAt, bi.UpdatedAt)
	return err
}

func (r *BattleInstanceRepository) FindByBattleID(ctx context.Context, battleID string) (BattleInstance, error) {
	var record BattleInstance
	err := r.db.QueryRow(ctx, `
		SELECT battle_id, assignment_id, match_id, ds_instance_id,
		       server_host, server_port, state,
		       started_at, ready_at, finished_at, finalized_at, reaped_at,
		       created_at, updated_at
		FROM battle_instances
		WHERE battle_id = $1
	`, battleID).Scan(
		&record.BattleID, &record.AssignmentID, &record.MatchID, &record.DSInstanceID,
		&record.ServerHost, &record.ServerPort, &record.State,
		&record.StartedAt, &record.ReadyAt, &record.FinishedAt, &record.FinalizedAt, &record.ReapedAt,
		&record.CreatedAt, &record.UpdatedAt,
	)
	if err != nil {
		return BattleInstance{}, mapNotFound(err)
	}
	return record, nil
}

func (r *BattleInstanceRepository) FindByAssignmentID(ctx context.Context, assignmentID string) (BattleInstance, error) {
	var record BattleInstance
	err := r.db.QueryRow(ctx, `
		SELECT battle_id, assignment_id, match_id, ds_instance_id,
		       server_host, server_port, state,
		       started_at, ready_at, finished_at, finalized_at, reaped_at,
		       created_at, updated_at
		FROM battle_instances
		WHERE assignment_id = $1
	`, assignmentID).Scan(
		&record.BattleID, &record.AssignmentID, &record.MatchID, &record.DSInstanceID,
		&record.ServerHost, &record.ServerPort, &record.State,
		&record.StartedAt, &record.ReadyAt, &record.FinishedAt, &record.FinalizedAt, &record.ReapedAt,
		&record.CreatedAt, &record.UpdatedAt,
	)
	if err != nil {
		return BattleInstance{}, mapNotFound(err)
	}
	return record, nil
}

func (r *BattleInstanceRepository) UpdateState(ctx context.Context, battleID string, state string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE battle_instances
		SET state = $2,
		    started_at = CASE WHEN $2 = 'starting' THEN NOW() ELSE started_at END,
		    ready_at = CASE WHEN $2 = 'ready' THEN NOW() ELSE ready_at END,
		    finished_at = CASE WHEN $2 = 'finished' THEN NOW() ELSE finished_at END,
		    finalized_at = CASE WHEN $2 = 'finalized' THEN NOW() ELSE finalized_at END,
		    reaped_at = CASE WHEN $2 = 'reaped' THEN NOW() ELSE reaped_at END,
		    updated_at = NOW()
		WHERE battle_id = $1
	`, battleID, state)
	return err
}

func (r *BattleInstanceRepository) UpdateDSInfo(ctx context.Context, battleID string, dsInstanceID string, host string, port int) error {
	_, err := r.db.Exec(ctx, `
		UPDATE battle_instances
		SET ds_instance_id = $2,
		    server_host = $3,
		    server_port = $4,
		    updated_at = NOW()
		WHERE battle_id = $1
	`, battleID, dsInstanceID, host, port)
	return err
}
