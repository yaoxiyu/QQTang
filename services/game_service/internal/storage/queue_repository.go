package storage

import (
	"context"
	"time"
)

type QueueEntry struct {
	QueueEntryID         string
	QueueType            string
	QueueKey             string
	SeasonID             string
	AccountID            string
	ProfileID            string
	DeviceSessionID      string
	ModeID               string
	RuleSetID            string
	PreferredMapPoolID   string
	RatingSnapshot       int
	EnqueueUnixSec       int64
	LastHeartbeatUnixSec int64
	State                string
	AssignmentID         string
	AssignmentRevision   int
	TerminalReason       string
	CancelReason         string
	CreatedAt            time.Time
	UpdatedAt            time.Time
}

type QueueRepository struct {
	db DBTX
}

func NewQueueRepository(db DBTX) *QueueRepository {
	return &QueueRepository{db: db}
}

func (r *QueueRepository) Insert(ctx context.Context, entry QueueEntry) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO matchmaking_queue_entries (
			queue_entry_id, queue_type, queue_key, season_id, account_id, profile_id, device_session_id,
			mode_id, rule_set_id, preferred_map_pool_id, rating_snapshot, enqueue_unix_sec,
			last_heartbeat_unix_sec, state, assignment_id, assignment_revision, terminal_reason, cancel_reason, created_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,NULLIF($15, ''),$16,$17,$18,$19,$20
		)
	`, entry.QueueEntryID, entry.QueueType, entry.QueueKey, entry.SeasonID, entry.AccountID, entry.ProfileID, entry.DeviceSessionID,
		entry.ModeID, entry.RuleSetID, entry.PreferredMapPoolID, entry.RatingSnapshot, entry.EnqueueUnixSec,
		entry.LastHeartbeatUnixSec, entry.State, entry.AssignmentID, entry.AssignmentRevision, canonicalTerminalReason(entry.TerminalReason, entry.CancelReason), entry.CancelReason, entry.CreatedAt, entry.UpdatedAt)
	return err
}

func (r *QueueRepository) FindActiveByProfileID(ctx context.Context, profileID string) (QueueEntry, error) {
	return scanQueueEntry(r.db.QueryRow(ctx, `
		SELECT queue_entry_id, queue_type, queue_key, season_id, account_id, profile_id, device_session_id,
		       mode_id, rule_set_id, preferred_map_pool_id, rating_snapshot, enqueue_unix_sec, last_heartbeat_unix_sec,
		       state, COALESCE(assignment_id, ''), assignment_revision, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_queue_entries
		WHERE profile_id = $1 AND state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready')
		ORDER BY created_at DESC
		LIMIT 1
	`, profileID))
}

func (r *QueueRepository) FindByQueueEntryID(ctx context.Context, queueEntryID string) (QueueEntry, error) {
	return scanQueueEntry(r.db.QueryRow(ctx, `
		SELECT queue_entry_id, queue_type, queue_key, season_id, account_id, profile_id, device_session_id,
		       mode_id, rule_set_id, preferred_map_pool_id, rating_snapshot, enqueue_unix_sec, last_heartbeat_unix_sec,
		       state, COALESCE(assignment_id, ''), assignment_revision, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_queue_entries
		WHERE queue_entry_id = $1
	`, queueEntryID))
}

func (r *QueueRepository) FindQueuedByKey(ctx context.Context, queueKey string, limit int, minHeartbeatUnixSec int64) ([]QueueEntry, error) {
	rows, err := r.db.Query(ctx, `
		SELECT queue_entry_id, queue_type, queue_key, season_id, account_id, profile_id, device_session_id,
		       mode_id, rule_set_id, preferred_map_pool_id, rating_snapshot, enqueue_unix_sec, last_heartbeat_unix_sec,
		       state, COALESCE(assignment_id, ''), assignment_revision, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_queue_entries
		WHERE queue_key = $1 AND state = 'queued'
		  AND last_heartbeat_unix_sec >= $3
		ORDER BY enqueue_unix_sec ASC, created_at ASC
		LIMIT $2
	`, queueKey, limit, minHeartbeatUnixSec)
	if err != nil {
		return nil, err
	}
	if rows == nil {
		return []QueueEntry{}, nil
	}
	defer rows.Close()

	entries := []QueueEntry{}
	for rows.Next() {
		entry, err := scanQueueEntry(rows)
		if err != nil {
			return nil, err
		}
		entries = append(entries, entry)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return entries, nil
}

func (r *QueueRepository) FindQueuedByKeyForUpdate(ctx context.Context, queueKey string, limit int, minHeartbeatUnixSec int64) ([]QueueEntry, error) {
	rows, err := r.db.Query(ctx, `
		SELECT queue_entry_id, queue_type, queue_key, season_id, account_id, profile_id, device_session_id,
		       mode_id, rule_set_id, preferred_map_pool_id, rating_snapshot, enqueue_unix_sec, last_heartbeat_unix_sec,
		       state, COALESCE(assignment_id, ''), assignment_revision, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_queue_entries
		WHERE queue_key = $1 AND state = 'queued'
		  AND last_heartbeat_unix_sec >= $3
		ORDER BY enqueue_unix_sec ASC, created_at ASC
		LIMIT $2
		FOR UPDATE SKIP LOCKED
	`, queueKey, limit, minHeartbeatUnixSec)
	if err != nil {
		return nil, err
	}
	if rows == nil {
		return []QueueEntry{}, nil
	}
	defer rows.Close()

	entries := []QueueEntry{}
	for rows.Next() {
		entry, err := scanQueueEntry(rows)
		if err != nil {
			return nil, err
		}
		entries = append(entries, entry)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return entries, nil
}

func (r *QueueRepository) UpdateStatus(ctx context.Context, queueEntryID string, state string, cancelReason string, assignmentID string, assignmentRevision int, heartbeatUnixSec int64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_queue_entries
		SET state = $2,
		    terminal_reason = $3,
		    cancel_reason = $3,
		    assignment_id = NULLIF($4, ''),
		    assignment_revision = $5,
		    last_heartbeat_unix_sec = $6,
		    updated_at = NOW()
		WHERE queue_entry_id = $1
	`, queueEntryID, state, cancelReason, assignmentID, assignmentRevision, heartbeatUnixSec)
	return err
}

func (r *QueueRepository) UpdateStatusIfCurrentState(ctx context.Context, queueEntryID string, expectedState string, state string, cancelReason string, assignmentID string, assignmentRevision int, heartbeatUnixSec int64) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE matchmaking_queue_entries
		SET state = $3,
		    terminal_reason = $4,
		    cancel_reason = $4,
		    assignment_id = NULLIF($5, ''),
		    assignment_revision = $6,
		    last_heartbeat_unix_sec = $7,
		    updated_at = NOW()
		WHERE queue_entry_id = $1
		  AND state = $2
	`, queueEntryID, expectedState, state, cancelReason, assignmentID, assignmentRevision, heartbeatUnixSec)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrConcurrentStateChanged
	}
	return nil
}

func scanQueueEntry(row interface{ Scan(dest ...any) error }) (QueueEntry, error) {
	var entry QueueEntry
	err := row.Scan(
		&entry.QueueEntryID,
		&entry.QueueType,
		&entry.QueueKey,
		&entry.SeasonID,
		&entry.AccountID,
		&entry.ProfileID,
		&entry.DeviceSessionID,
		&entry.ModeID,
		&entry.RuleSetID,
		&entry.PreferredMapPoolID,
		&entry.RatingSnapshot,
		&entry.EnqueueUnixSec,
		&entry.LastHeartbeatUnixSec,
		&entry.State,
		&entry.AssignmentID,
		&entry.AssignmentRevision,
		&entry.TerminalReason,
		&entry.CancelReason,
		&entry.CreatedAt,
		&entry.UpdatedAt,
	)
	if err != nil {
		return QueueEntry{}, mapNotFound(err)
	}
	if entry.TerminalReason == "" {
		entry.TerminalReason = entry.CancelReason
	}
	return entry, nil
}

func canonicalTerminalReason(terminalReason string, cancelReason string) string {
	if terminalReason != "" {
		return terminalReason
	}
	return cancelReason
}
