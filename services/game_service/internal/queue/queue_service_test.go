package queue

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

type fakeQueueRow struct {
	values []any
	err    error
}

func (r fakeQueueRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for idx := range dest {
		reflect.ValueOf(dest[idx]).Elem().Set(reflect.ValueOf(r.values[idx]))
	}
	return nil
}

type fakeQueueDB struct {
	entriesByProfile map[string]storage.QueueEntry
	entriesByID      map[string]storage.QueueEntry
}

func newFakeQueueDB() *fakeQueueDB {
	return &fakeQueueDB{
		entriesByProfile: map[string]storage.QueueEntry{},
		entriesByID:      map[string]storage.QueueEntry{},
	}
}

func (db *fakeQueueDB) Exec(_ context.Context, sql string, arguments ...any) (pgconn.CommandTag, error) {
	switch {
	case strings.Contains(sql, "INSERT INTO matchmaking_queue_entries"):
		entry := storage.QueueEntry{
			QueueEntryID:         arguments[0].(string),
			QueueType:            arguments[1].(string),
			QueueKey:             arguments[2].(string),
			SeasonID:             arguments[3].(string),
			AccountID:            arguments[4].(string),
			ProfileID:            arguments[5].(string),
			DeviceSessionID:      arguments[6].(string),
			ModeID:               arguments[7].(string),
			RuleSetID:            arguments[8].(string),
			PreferredMapPoolID:   arguments[9].(string),
			RatingSnapshot:       arguments[10].(int),
			EnqueueUnixSec:       arguments[11].(int64),
			LastHeartbeatUnixSec: arguments[12].(int64),
			State:                arguments[13].(string),
			AssignmentID:         arguments[14].(string),
			AssignmentRevision:   arguments[15].(int),
			CancelReason:         arguments[16].(string),
			CreatedAt:            arguments[17].(time.Time),
			UpdatedAt:            arguments[18].(time.Time),
		}
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
	case strings.Contains(sql, "UPDATE matchmaking_queue_entries"):
		entry := db.entriesByID[arguments[0].(string)]
		entry.State = arguments[1].(string)
		entry.CancelReason = arguments[2].(string)
		entry.AssignmentID = arguments[3].(string)
		entry.AssignmentRevision = arguments[4].(int)
		entry.LastHeartbeatUnixSec = arguments[5].(int64)
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
	}
	return pgconn.NewCommandTag("OK"), nil
}

func (db *fakeQueueDB) Query(_ context.Context, _ string, _ ...any) (pgx.Rows, error) {
	return nil, nil
}

func (db *fakeQueueDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "WHERE profile_id = $1"):
		profileID := args[0].(string)
		entry, ok := db.entriesByProfile[profileID]
		if !ok || (entry.State != "queued" && entry.State != "assigned" && entry.State != "committing") {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: queueEntryRow(entry)}
	case strings.Contains(sql, "WHERE queue_entry_id = $1"):
		queueEntryID := args[0].(string)
		entry, ok := db.entriesByID[queueEntryID]
		if !ok {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: queueEntryRow(entry)}
	default:
		return fakeQueueRow{err: pgx.ErrNoRows}
	}
}

func queueEntryRow(entry storage.QueueEntry) []any {
	return []any{
		entry.QueueEntryID,
		entry.QueueType,
		entry.QueueKey,
		entry.SeasonID,
		entry.AccountID,
		entry.ProfileID,
		entry.DeviceSessionID,
		entry.ModeID,
		entry.RuleSetID,
		entry.PreferredMapPoolID,
		entry.RatingSnapshot,
		entry.EnqueueUnixSec,
		entry.LastHeartbeatUnixSec,
		entry.State,
		entry.AssignmentID,
		entry.AssignmentRevision,
		entry.CancelReason,
		entry.CreatedAt,
		entry.UpdatedAt,
	}
}

func TestEnterQueueCreatesQueuedEntry(t *testing.T) {
	db := newFakeQueueDB()
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), 30*time.Second)

	status, err := service.EnterQueue(context.Background(), EnterQueueInput{
		AccountID:       "account_1",
		ProfileID:       "profile_1",
		DeviceSessionID: "device_1",
		QueueType:       "ranked",
		ModeID:          "ranked_mode",
		RuleSetID:       "rule_standard",
	})
	if err != nil {
		t.Fatalf("EnterQueue returned error: %v", err)
	}
	if status.QueueState != "queued" {
		t.Fatalf("expected queued state, got %s", status.QueueState)
	}
	if status.QueueEntryID == "" {
		t.Fatal("expected queue entry id to be generated")
	}
	if status.QueueKey != BuildQueueKey("ranked", "ranked_mode", "rule_standard") {
		t.Fatalf("unexpected queue key: %s", status.QueueKey)
	}
}

func TestCancelQueueMarksEntryCancelled(t *testing.T) {
	db := newFakeQueueDB()
	now := time.Now().UTC()
	entry := storage.QueueEntry{
		QueueEntryID:         "queue_test",
		QueueType:            "ranked",
		QueueKey:             BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		SeasonID:             "season_s1",
		AccountID:            "account_1",
		ProfileID:            "profile_1",
		DeviceSessionID:      "device_1",
		ModeID:               "ranked_mode",
		RuleSetID:            "rule_standard",
		RatingSnapshot:       1000,
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		State:                "queued",
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	db.entriesByID[entry.QueueEntryID] = entry
	db.entriesByProfile[entry.ProfileID] = entry
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), 30*time.Second)

	status, err := service.CancelQueue(context.Background(), "profile_1", "queue_test")
	if err != nil {
		t.Fatalf("CancelQueue returned error: %v", err)
	}
	if status.QueueState != "cancelled" {
		t.Fatalf("expected cancelled state, got %s", status.QueueState)
	}
	cancelled := db.entriesByID["queue_test"]
	if cancelled.State != "cancelled" {
		t.Fatalf("expected repository state to be cancelled, got %s", cancelled.State)
	}
	if cancelled.CancelReason != "client_cancelled" {
		t.Fatalf("expected cancel reason client_cancelled, got %s", cancelled.CancelReason)
	}
}
