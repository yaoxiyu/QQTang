package storage

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5"
)

type PartyQueueEntry struct {
	PartyQueueEntryID    string
	PartyRoomID          string
	QueueType            string
	MatchFormatID        string
	PartySize            int
	CaptainAccountID     string
	CaptainProfileID     string
	SelectedModeIDs      []string
	QueueKey             string
	State                string
	AssignmentID         string
	AssignmentRevision   int
	EnqueueUnixSec       int64
	LastHeartbeatUnixSec int64
	TerminalReason       string
	CancelReason         string
	CreatedAt            time.Time
	UpdatedAt            time.Time
}

type PartyQueueRepository struct {
	db DBTX
}

func NewPartyQueueRepository(db DBTX) *PartyQueueRepository {
	return &PartyQueueRepository{db: db}
}

func (r *PartyQueueRepository) Insert(ctx context.Context, entry PartyQueueEntry) error {
	selectedModeIDsJSON, err := json.Marshal(entry.SelectedModeIDs)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(ctx, `
		INSERT INTO matchmaking_party_queue_entries (
			party_queue_entry_id, party_room_id, queue_type, match_format_id, party_size,
			captain_account_id, captain_profile_id, selected_mode_ids_json, queue_key,
			state, assignment_id, assignment_revision, enqueue_unix_sec, last_heartbeat_unix_sec,
			terminal_reason, cancel_reason, created_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10,NULLIF($11, ''),$12,$13,$14,$15,$16,$17,$18
		)
	`, entry.PartyQueueEntryID, entry.PartyRoomID, entry.QueueType, entry.MatchFormatID, entry.PartySize,
		entry.CaptainAccountID, entry.CaptainProfileID, string(selectedModeIDsJSON), entry.QueueKey,
		entry.State, entry.AssignmentID, entry.AssignmentRevision, entry.EnqueueUnixSec,
		entry.LastHeartbeatUnixSec, canonicalTerminalReason(entry.TerminalReason, entry.CancelReason), entry.CancelReason, entry.CreatedAt, entry.UpdatedAt)
	return err
}

func (r *PartyQueueRepository) FindActiveByRoomID(ctx context.Context, partyRoomID string) (PartyQueueEntry, error) {
	return scanPartyQueueEntry(r.db.QueryRow(ctx, `
		SELECT party_queue_entry_id, party_room_id, queue_type, match_format_id, party_size,
		       captain_account_id, captain_profile_id, selected_mode_ids_json, queue_key,
		       state, COALESCE(assignment_id, ''), assignment_revision, enqueue_unix_sec,
		       last_heartbeat_unix_sec, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_party_queue_entries
		WHERE party_room_id = $1 AND state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready')
		ORDER BY created_at DESC
		LIMIT 1
	`, partyRoomID))
}

func (r *PartyQueueRepository) FindByEntryID(ctx context.Context, entryID string) (PartyQueueEntry, error) {
	return scanPartyQueueEntry(r.db.QueryRow(ctx, `
		SELECT party_queue_entry_id, party_room_id, queue_type, match_format_id, party_size,
		       captain_account_id, captain_profile_id, selected_mode_ids_json, queue_key,
		       state, COALESCE(assignment_id, ''), assignment_revision, enqueue_unix_sec,
		       last_heartbeat_unix_sec, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_party_queue_entries
		WHERE party_queue_entry_id = $1
	`, entryID))
}

func (r *PartyQueueRepository) FindQueuedByKey(ctx context.Context, queueKey string, limit int, minHeartbeatUnixSec int64) ([]PartyQueueEntry, error) {
	rows, err := r.db.Query(ctx, `
		SELECT party_queue_entry_id, party_room_id, queue_type, match_format_id, party_size,
		       captain_account_id, captain_profile_id, selected_mode_ids_json, queue_key,
		       state, COALESCE(assignment_id, ''), assignment_revision, enqueue_unix_sec,
		       last_heartbeat_unix_sec, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_party_queue_entries
		WHERE queue_key = $1 AND state = 'queued'
		  AND last_heartbeat_unix_sec >= $3
		ORDER BY enqueue_unix_sec ASC, created_at ASC
		LIMIT $2
	`, queueKey, limit, minHeartbeatUnixSec)
	return scanPartyQueueEntries(rows, err)
}

func (r *PartyQueueRepository) FindQueuedByKeyForUpdate(ctx context.Context, queueKey string, limit int, minHeartbeatUnixSec int64) ([]PartyQueueEntry, error) {
	rows, err := r.db.Query(ctx, `
		SELECT party_queue_entry_id, party_room_id, queue_type, match_format_id, party_size,
		       captain_account_id, captain_profile_id, selected_mode_ids_json, queue_key,
		       state, COALESCE(assignment_id, ''), assignment_revision, enqueue_unix_sec,
		       last_heartbeat_unix_sec, COALESCE(NULLIF(terminal_reason, ''), cancel_reason, ''), cancel_reason, created_at, updated_at
		FROM matchmaking_party_queue_entries
		WHERE queue_key = $1 AND state = 'queued'
		  AND last_heartbeat_unix_sec >= $3
		ORDER BY enqueue_unix_sec ASC, created_at ASC
		LIMIT $2
		FOR UPDATE SKIP LOCKED
	`, queueKey, limit, minHeartbeatUnixSec)
	return scanPartyQueueEntries(rows, err)
}

func (r *PartyQueueRepository) UpdateStatus(ctx context.Context, entryID string, state string, cancelReason string, assignmentID string, assignmentRevision int, heartbeatUnixSec int64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE matchmaking_party_queue_entries
		SET state = $2,
		    terminal_reason = $3,
		    cancel_reason = $3,
		    assignment_id = NULLIF($4, ''),
		    assignment_revision = $5,
		    last_heartbeat_unix_sec = $6,
		    updated_at = NOW()
		WHERE party_queue_entry_id = $1
	`, entryID, state, cancelReason, assignmentID, assignmentRevision, heartbeatUnixSec)
	return err
}

func (r *PartyQueueRepository) UpdateStatusIfCurrentState(ctx context.Context, entryID string, expectedState string, state string, cancelReason string, assignmentID string, assignmentRevision int, heartbeatUnixSec int64) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE matchmaking_party_queue_entries
		SET state = $3,
		    terminal_reason = $4,
		    cancel_reason = $4,
		    assignment_id = NULLIF($5, ''),
		    assignment_revision = $6,
		    last_heartbeat_unix_sec = $7,
		    updated_at = NOW()
		WHERE party_queue_entry_id = $1
		  AND state = $2
	`, entryID, expectedState, state, cancelReason, assignmentID, assignmentRevision, heartbeatUnixSec)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrConcurrentStateChanged
	}
	return nil
}

func scanPartyQueueEntries(rows pgx.Rows, err error) ([]PartyQueueEntry, error) {
	if err != nil {
		return nil, err
	}
	if rows == nil {
		return []PartyQueueEntry{}, nil
	}
	defer rows.Close()
	entries := []PartyQueueEntry{}
	for rows.Next() {
		entry, err := scanPartyQueueEntry(rows)
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

func scanPartyQueueEntry(row interface{ Scan(dest ...any) error }) (PartyQueueEntry, error) {
	var entry PartyQueueEntry
	var selectedModeIDsJSON []byte
	err := row.Scan(
		&entry.PartyQueueEntryID,
		&entry.PartyRoomID,
		&entry.QueueType,
		&entry.MatchFormatID,
		&entry.PartySize,
		&entry.CaptainAccountID,
		&entry.CaptainProfileID,
		&selectedModeIDsJSON,
		&entry.QueueKey,
		&entry.State,
		&entry.AssignmentID,
		&entry.AssignmentRevision,
		&entry.EnqueueUnixSec,
		&entry.LastHeartbeatUnixSec,
		&entry.TerminalReason,
		&entry.CancelReason,
		&entry.CreatedAt,
		&entry.UpdatedAt,
	)
	if err != nil {
		return PartyQueueEntry{}, mapNotFound(err)
	}
	if len(selectedModeIDsJSON) > 0 {
		_ = json.Unmarshal(selectedModeIDsJSON, &entry.SelectedModeIDs)
	}
	if entry.TerminalReason == "" {
		entry.TerminalReason = entry.CancelReason
	}
	return entry, nil
}
