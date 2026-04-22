package queue

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

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
	entriesByProfile    map[string]storage.QueueEntry
	entriesByID         map[string]storage.QueueEntry
	partyEntriesByRoom  map[string]storage.PartyQueueEntry
	partyEntriesByID    map[string]storage.PartyQueueEntry
	partyMembersByEntry map[string][]storage.PartyQueueMember
	assignmentsByID     map[string]storage.Assignment
	membersByKey        map[string]storage.AssignmentMember
}

func newFakeQueueDB() *fakeQueueDB {
	return &fakeQueueDB{
		entriesByProfile:    map[string]storage.QueueEntry{},
		entriesByID:         map[string]storage.QueueEntry{},
		partyEntriesByRoom:  map[string]storage.PartyQueueEntry{},
		partyEntriesByID:    map[string]storage.PartyQueueEntry{},
		partyMembersByEntry: map[string][]storage.PartyQueueMember{},
		assignmentsByID:     map[string]storage.Assignment{},
		membersByKey:        map[string]storage.AssignmentMember{},
	}
}

func (db *fakeQueueDB) Exec(_ context.Context, sql string, arguments ...any) (pgconn.CommandTag, error) {
	switch {
	case strings.Contains(sql, "INSERT INTO matchmaking_party_queue_entries"):
		entry := storage.PartyQueueEntry{
			PartyQueueEntryID:    arguments[0].(string),
			PartyRoomID:          arguments[1].(string),
			QueueType:            arguments[2].(string),
			MatchFormatID:        arguments[3].(string),
			PartySize:            arguments[4].(int),
			CaptainAccountID:     arguments[5].(string),
			CaptainProfileID:     arguments[6].(string),
			QueueKey:             arguments[8].(string),
			State:                arguments[9].(string),
			AssignmentID:         arguments[10].(string),
			AssignmentRevision:   arguments[11].(int),
			EnqueueUnixSec:       arguments[12].(int64),
			LastHeartbeatUnixSec: arguments[13].(int64),
			TerminalReason:       arguments[14].(string),
			CancelReason:         arguments[15].(string),
			CreatedAt:            arguments[16].(time.Time),
			UpdatedAt:            arguments[17].(time.Time),
		}
		if raw, ok := arguments[7].(string); ok {
			entry.SelectedModeIDs = selectedModeIDsFromJSON(raw)
		}
		db.partyEntriesByRoom[entry.PartyRoomID] = entry
		db.partyEntriesByID[entry.PartyQueueEntryID] = entry
		return pgconn.NewCommandTag("INSERT 0 1"), nil
	case strings.Contains(sql, "INSERT INTO matchmaking_party_queue_members"):
		member := storage.PartyQueueMember{
			PartyQueueEntryID: arguments[0].(string),
			AccountID:         arguments[1].(string),
			ProfileID:         arguments[2].(string),
			DeviceSessionID:   arguments[3].(string),
			SeatIndex:         arguments[4].(int),
			RatingSnapshot:    arguments[5].(int),
			CreatedAt:         arguments[6].(time.Time),
			UpdatedAt:         arguments[7].(time.Time),
		}
		db.partyMembersByEntry[member.PartyQueueEntryID] = append(db.partyMembersByEntry[member.PartyQueueEntryID], member)
		return pgconn.NewCommandTag("INSERT 0 1"), nil
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
			TerminalReason:       arguments[16].(string),
			CancelReason:         arguments[17].(string),
			CreatedAt:            arguments[18].(time.Time),
			UpdatedAt:            arguments[19].(time.Time),
		}
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
		return pgconn.NewCommandTag("INSERT 0 1"), nil
	case strings.Contains(sql, "INSERT INTO matchmaking_assignments"):
		assignment := storage.Assignment{
			AssignmentID:           arguments[0].(string),
			QueueKey:               arguments[1].(string),
			QueueType:              arguments[2].(string),
			SeasonID:               arguments[3].(string),
			RoomID:                 arguments[4].(string),
			RoomKind:               arguments[5].(string),
			MatchID:                arguments[6].(string),
			ModeID:                 arguments[7].(string),
			RuleSetID:              arguments[8].(string),
			MapID:                  arguments[9].(string),
			ServerHost:             arguments[10].(string),
			ServerPort:             arguments[11].(int),
			CaptainAccountID:       arguments[12].(string),
			AssignmentRevision:     arguments[13].(int),
			ExpectedMemberCount:    arguments[14].(int),
			State:                  arguments[15].(string),
			CaptainDeadlineUnixSec: arguments[16].(int64),
			CommitDeadlineUnixSec:  arguments[17].(int64),
			CreatedAt:              arguments[18].(time.Time),
			UpdatedAt:              arguments[19].(time.Time),
			SourceRoomID:           arguments[20].(string),
			SourceRoomKind:         arguments[21].(string),
			BattleID:               arguments[22].(string),
			DSInstanceID:           arguments[23].(string),
			BattleServerHost:       arguments[24].(string),
			BattleServerPort:       arguments[25].(int),
			AllocationState:        arguments[26].(string),
			AllocationErrorCode:    arguments[27].(string),
			AllocationLastError:    arguments[28].(string),
			RoomReturnPolicy:       arguments[29].(string),
		}
		db.assignmentsByID[assignment.AssignmentID] = assignment
		return pgconn.NewCommandTag("INSERT 0 1"), nil
	case strings.Contains(sql, "INSERT INTO matchmaking_assignment_members"):
		member := storage.AssignmentMember{
			AssignmentID:       arguments[0].(string),
			AccountID:          arguments[1].(string),
			ProfileID:          arguments[2].(string),
			TicketRole:         arguments[3].(string),
			AssignedTeamID:     arguments[4].(int),
			RatingBefore:       arguments[5].(int),
			JoinState:          arguments[6].(string),
			ResultState:        arguments[7].(string),
			CreatedAt:          arguments[8].(time.Time),
			UpdatedAt:          arguments[9].(time.Time),
			SourceRoomID:       arguments[10].(string),
			SourceRoomMemberID: arguments[11].(string),
			BattleJoinState:    arguments[12].(string),
			RoomReturnState:    arguments[13].(string),
		}
		db.membersByKey[member.AssignmentID+":"+member.AccountID] = member
		return pgconn.NewCommandTag("INSERT 0 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_queue_entries") && strings.Contains(sql, "cancel_reason"):
		entry := db.entriesByID[arguments[0].(string)]
		if strings.Contains(sql, "AND state = $2") {
			if entry.State != arguments[1].(string) {
				return pgconn.NewCommandTag("UPDATE 0"), nil
			}
			entry.State = arguments[2].(string)
			entry.TerminalReason = arguments[3].(string)
			entry.CancelReason = arguments[3].(string)
			entry.AssignmentID = arguments[4].(string)
			entry.AssignmentRevision = arguments[5].(int)
			entry.LastHeartbeatUnixSec = arguments[6].(int64)
		} else {
			entry.State = arguments[1].(string)
			entry.TerminalReason = arguments[2].(string)
			entry.CancelReason = arguments[2].(string)
			entry.AssignmentID = arguments[3].(string)
			entry.AssignmentRevision = arguments[4].(int)
			entry.LastHeartbeatUnixSec = arguments[5].(int64)
		}
		if entry.QueueEntryID == "" {
			return pgconn.NewCommandTag("UPDATE 0"), nil
		}
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_assignments") && strings.Contains(sql, "allocation_state = 'alloc_failed'"):
		assignment := db.assignmentsByID[arguments[0].(string)]
		assignment.AllocationState = "alloc_failed"
		assignment.BattleID = arguments[1].(string)
		assignment.DSInstanceID = ""
		assignment.BattleServerHost = ""
		assignment.BattleServerPort = 0
		assignment.AllocationErrorCode = arguments[2].(string)
		assignment.AllocationLastError = arguments[3].(string)
		db.assignmentsByID[assignment.AssignmentID] = assignment
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_assignments") && strings.Contains(sql, "allocation_state = $2"):
		assignment := db.assignmentsByID[arguments[0].(string)]
		assignment.AllocationState = arguments[1].(string)
		assignment.BattleID = arguments[2].(string)
		assignment.DSInstanceID = arguments[3].(string)
		assignment.BattleServerHost = arguments[4].(string)
		assignment.BattleServerPort = arguments[5].(int)
		assignment.AllocationErrorCode = ""
		assignment.AllocationLastError = ""
		db.assignmentsByID[assignment.AssignmentID] = assignment
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_assignments") && strings.Contains(sql, "captain_account_id"):
		assignment := db.assignmentsByID[arguments[0].(string)]
		assignment.CaptainAccountID = arguments[1].(string)
		assignment.AssignmentRevision = arguments[2].(int)
		assignment.CaptainDeadlineUnixSec = arguments[3].(int64)
		db.assignmentsByID[assignment.AssignmentID] = assignment
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_assignment_members") && strings.Contains(sql, "ticket_role"):
		assignmentID := arguments[0].(string)
		captainAccountID := arguments[1].(string)
		for key, member := range db.membersByKey {
			if member.AssignmentID != assignmentID {
				continue
			}
			if member.AccountID == captainAccountID {
				member.TicketRole = "create"
			} else {
				member.TicketRole = "join"
			}
			db.membersByKey[key] = member
		}
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "SET assignment_revision = $2"):
		assignmentID := arguments[0].(string)
		revision := arguments[1].(int)
		for key, entry := range db.entriesByID {
			if entry.AssignmentID != assignmentID || (entry.State != "assigned" && entry.State != "committing") {
				continue
			}
			entry.AssignmentRevision = revision
			db.entriesByID[key] = entry
			db.entriesByProfile[entry.ProfileID] = entry
		}
		return pgconn.NewCommandTag("UPDATE 1"), nil
	}
	return pgconn.NewCommandTag("OK"), nil
}

func (db *fakeQueueDB) Query(_ context.Context, sql string, args ...any) (pgx.Rows, error) {
	if strings.Contains(sql, "FROM matchmaking_assignment_members") {
		assignmentID := args[0].(string)
		members := []storage.AssignmentMember{}
		for _, member := range db.membersByKey {
			if member.AssignmentID == assignmentID {
				members = append(members, member)
			}
		}
		sort.Slice(members, func(i, j int) bool {
			return members[i].AccountID < members[j].AccountID
		})
		rows := &fakeQueueRows{}
		for _, member := range members {
			rows.values = append(rows.values, []any{
				member.AssignmentID,
				member.AccountID,
				member.ProfileID,
				member.TicketRole,
				member.AssignedTeamID,
				member.RatingBefore,
				member.JoinState,
				member.ResultState,
				member.CreatedAt,
				member.UpdatedAt,
				member.SourceRoomID,
				member.SourceRoomMemberID,
				member.BattleJoinState,
				member.RoomReturnState,
			})
		}
		return rows, nil
	}
	if !strings.Contains(sql, "WHERE queue_key = $1 AND state = 'queued'") {
		return &fakeQueueRows{}, nil
	}
	queueKey := args[0].(string)
	limit := args[1].(int)
	entries := []storage.QueueEntry{}
	for _, entry := range db.entriesByID {
		if entry.QueueKey == queueKey && entry.State == "queued" {
			entries = append(entries, entry)
		}
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].EnqueueUnixSec == entries[j].EnqueueUnixSec {
			return entries[i].CreatedAt.Before(entries[j].CreatedAt)
		}
		return entries[i].EnqueueUnixSec < entries[j].EnqueueUnixSec
	})
	if len(entries) > limit {
		entries = entries[:limit]
	}
	rows := &fakeQueueRows{}
	for _, entry := range entries {
		rows.values = append(rows.values, queueEntryRow(entry))
	}
	return rows, nil
}

func (db *fakeQueueDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "FROM matchmaking_party_queue_entries") && strings.Contains(sql, "WHERE party_room_id = $1"):
		partyRoomID := args[0].(string)
		entry, ok := db.partyEntriesByRoom[partyRoomID]
		if !ok || !isActivePartyQueueState(entry.State) {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: partyQueueEntryRow(entry)}
	case strings.Contains(sql, "FROM matchmaking_party_queue_entries") && strings.Contains(sql, "WHERE party_queue_entry_id = $1"):
		entryID := args[0].(string)
		entry, ok := db.partyEntriesByID[entryID]
		if !ok {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: partyQueueEntryRow(entry)}
	case strings.Contains(sql, "FROM matchmaking_assignments"):
		assignment, ok := db.assignmentsByID[args[0].(string)]
		if !ok {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: []any{
			assignment.AssignmentID,
			assignment.QueueKey,
			assignment.QueueType,
			assignment.SeasonID,
			assignment.RoomID,
			assignment.RoomKind,
			assignment.MatchID,
			assignment.ModeID,
			assignment.RuleSetID,
			assignment.MapID,
			assignment.ServerHost,
			assignment.ServerPort,
			assignment.CaptainAccountID,
			assignment.AssignmentRevision,
			assignment.ExpectedMemberCount,
			assignment.State,
			assignment.CaptainDeadlineUnixSec,
			assignment.CommitDeadlineUnixSec,
			assignment.FinalizedAt,
			assignment.CreatedAt,
			assignment.UpdatedAt,
			assignment.SourceRoomID,
			assignment.SourceRoomKind,
			assignment.BattleID,
			assignment.DSInstanceID,
			assignment.BattleServerHost,
			assignment.BattleServerPort,
			assignment.AllocationState,
			assignment.AllocationErrorCode,
			assignment.AllocationLastError,
			assignment.RoomReturnPolicy,
			assignment.AllocationStartedAt,
			assignment.BattleReadyAt,
			assignment.BattleFinishedAt,
			assignment.ReturnCompletedAt,
		}}
	case strings.Contains(sql, "FROM matchmaking_assignment_members"):
		member, ok := db.membersByKey[args[0].(string)+":"+args[1].(string)]
		if !ok {
			return fakeQueueRow{err: pgx.ErrNoRows}
		}
		return fakeQueueRow{values: []any{
			member.AssignmentID,
			member.AccountID,
			member.ProfileID,
			member.TicketRole,
			member.AssignedTeamID,
			member.RatingBefore,
			member.JoinState,
			member.ResultState,
			member.CreatedAt,
			member.UpdatedAt,
			member.SourceRoomID,
			member.SourceRoomMemberID,
			member.BattleJoinState,
			member.RoomReturnState,
		}}
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

func selectedModeIDsFromJSON(raw string) []string {
	trimmed := strings.TrimSpace(raw)
	trimmed = strings.TrimPrefix(trimmed, "[")
	trimmed = strings.TrimSuffix(trimmed, "]")
	if trimmed == "" {
		return nil
	}
	parts := strings.Split(trimmed, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		value := strings.Trim(strings.TrimSpace(part), `"`)
		if value != "" {
			result = append(result, value)
		}
	}
	return result
}

func isActivePartyQueueState(state string) bool {
	switch state {
	case "queued", "assignment_pending", "allocating_battle", "entry_ready":
		return true
	default:
		return false
	}
}

func partyQueueEntryRow(entry storage.PartyQueueEntry) []any {
	return []any{
		entry.PartyQueueEntryID,
		entry.PartyRoomID,
		entry.QueueType,
		entry.MatchFormatID,
		entry.PartySize,
		entry.CaptainAccountID,
		entry.CaptainProfileID,
		[]byte(`["` + strings.Join(entry.SelectedModeIDs, `","`) + `"]`),
		entry.QueueKey,
		entry.State,
		entry.AssignmentID,
		entry.AssignmentRevision,
		entry.EnqueueUnixSec,
		entry.LastHeartbeatUnixSec,
		entry.TerminalReason,
		entry.CancelReason,
		entry.CreatedAt,
		entry.UpdatedAt,
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
		entry.TerminalReason,
		entry.CancelReason,
		entry.CreatedAt,
		entry.UpdatedAt,
	}
}

type fakeQueueRows struct {
	values [][]any
	index  int
	closed bool
}

func (r *fakeQueueRows) Close() {
	r.closed = true
}

func (r *fakeQueueRows) Err() error {
	return nil
}

func (r *fakeQueueRows) CommandTag() pgconn.CommandTag {
	return pgconn.NewCommandTag("SELECT")
}

func (r *fakeQueueRows) FieldDescriptions() []pgconn.FieldDescription {
	return nil
}

func (r *fakeQueueRows) Next() bool {
	if r.index >= len(r.values) {
		r.Close()
		return false
	}
	r.index++
	return true
}

func (r *fakeQueueRows) Scan(dest ...any) error {
	current := r.values[r.index-1]
	for idx := range dest {
		reflect.ValueOf(dest[idx]).Elem().Set(reflect.ValueOf(current[idx]))
	}
	return nil
}

func (r *fakeQueueRows) Values() ([]any, error) {
	if r.index <= 0 || r.index > len(r.values) {
		return nil, nil
	}
	return r.values[r.index-1], nil
}

func (r *fakeQueueRows) RawValues() [][]byte {
	return nil
}

func (r *fakeQueueRows) Conn() *pgx.Conn {
	return nil
}

func TestEnterQueueCreatesQueuedEntry(t *testing.T) {
	db := newFakeQueueDB()
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)

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
	if status.QueuePhase != QueuePhaseQueued || status.QueueTerminalReason != QueueTerminalReasonNone {
		t.Fatalf("expected queued/none canonical status, got phase=%s reason=%s", status.QueuePhase, status.QueueTerminalReason)
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
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)

	status, err := service.CancelQueue(context.Background(), "profile_1", "queue_test")
	if err != nil {
		t.Fatalf("CancelQueue returned error: %v", err)
	}
	if status.QueueState != "cancelled" {
		t.Fatalf("expected cancelled state, got %s", status.QueueState)
	}
	if status.QueuePhase != QueuePhaseCompleted || status.QueueTerminalReason != QueueTerminalReasonClientCancelled {
		t.Fatalf("expected completed/client_cancelled canonical status, got phase=%s reason=%s", status.QueuePhase, status.QueueTerminalReason)
	}
	cancelled := db.entriesByID["queue_test"]
	if cancelled.State != "completed" {
		t.Fatalf("expected repository state to be completed, got %s", cancelled.State)
	}
	if cancelled.CancelReason != "client_cancelled" {
		t.Fatalf("expected cancel reason client_cancelled, got %s", cancelled.CancelReason)
	}
}

func TestEnterQueueFormsAssignmentWhenFourthMemberArrives(t *testing.T) {
	db := newFakeQueueDB()
	queueKey := BuildQueueKey("ranked", "ranked_mode", "rule_standard")
	now := time.Now().UTC()
	for idx := 0; idx < 3; idx++ {
		entry := storage.QueueEntry{
			QueueEntryID:         "queue_seed_" + string(rune('a'+idx)),
			QueueType:            "ranked",
			QueueKey:             queueKey,
			SeasonID:             "season_s1",
			AccountID:            "account_seed_" + string(rune('a'+idx)),
			ProfileID:            "profile_seed_" + string(rune('a'+idx)),
			DeviceSessionID:      "device_seed",
			ModeID:               "ranked_mode",
			RuleSetID:            "rule_standard",
			RatingSnapshot:       1000 + idx,
			EnqueueUnixSec:       now.Add(time.Duration(idx) * time.Second).Unix(),
			LastHeartbeatUnixSec: now.Unix(),
			State:                "queued",
			CreatedAt:            now.Add(time.Duration(idx) * time.Second),
			UpdatedAt:            now.Add(time.Duration(idx) * time.Second),
		}
		db.entriesByID[entry.QueueEntryID] = entry
		db.entriesByProfile[entry.ProfileID] = entry
	}
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	service.ConfigureDefaults(AssignmentDefaults{
		SeasonID:               "season_test",
		MapID:                  "map_test",
		DSHost:                 "10.0.0.2",
		DSPort:                 9100,
		CaptainDeadlineSeconds: 20,
		CommitDeadlineSeconds:  60,
	})

	status, err := service.EnterQueue(context.Background(), EnterQueueInput{
		AccountID:       "account_4",
		ProfileID:       "profile_4",
		DeviceSessionID: "device_4",
		QueueType:       "ranked",
		ModeID:          "ranked_mode",
		RuleSetID:       "rule_standard",
	})
	if err != nil {
		t.Fatalf("EnterQueue returned error: %v", err)
	}
	if status.QueueState != "assigned" {
		t.Fatalf("expected assigned status for fourth member, got %s", status.QueueState)
	}
	if len(db.assignmentsByID) != 1 {
		t.Fatalf("expected one assignment, got %d", len(db.assignmentsByID))
	}
	var assignment storage.Assignment
	for _, record := range db.assignmentsByID {
		assignment = record
	}
	if assignment.ExpectedMemberCount != 4 || assignment.RoomKind != "matchmade_room" {
		t.Fatalf("unexpected assignment policy: %+v", assignment)
	}
	if assignment.ServerHost != "10.0.0.2" || assignment.ServerPort != 9100 {
		t.Fatalf("unexpected DS endpoint: %s:%d", assignment.ServerHost, assignment.ServerPort)
	}
	if assignment.SeasonID != "season_test" || assignment.MapID != "map_test" {
		t.Fatalf("unexpected assignment defaults: season=%s map=%s", assignment.SeasonID, assignment.MapID)
	}
	if len(db.membersByKey) != 4 {
		t.Fatalf("expected four assignment members, got %d", len(db.membersByKey))
	}
	createCount := 0
	for _, member := range db.membersByKey {
		if member.TicketRole == "create" {
			createCount++
		}
		if member.AssignedTeamID < 1 || member.AssignedTeamID > 2 {
			t.Fatalf("unexpected team id %d", member.AssignedTeamID)
		}
	}
	if createCount != 1 {
		t.Fatalf("expected exactly one captain create role, got %d", createCount)
	}
}

func TestEnterQueueFormsOneVOneAssignmentWhenSecondMemberArrives(t *testing.T) {
	db := newFakeQueueDB()
	queueKey := BuildQueueKey("casual", "1v1", "mode_classic", "rule_standard")
	now := time.Now().UTC()
	seed := storage.QueueEntry{
		QueueEntryID:         "queue_seed_a",
		QueueType:            "casual",
		QueueKey:             queueKey,
		SeasonID:             "season_s1",
		AccountID:            "account_seed_a",
		ProfileID:            "profile_seed_a",
		DeviceSessionID:      "device_seed",
		ModeID:               "mode_classic",
		RuleSetID:            "rule_standard",
		PreferredMapPoolID:   "map_classic_square",
		RatingSnapshot:       1000,
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		State:                "queued",
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	db.entriesByID[seed.QueueEntryID] = seed
	db.entriesByProfile[seed.ProfileID] = seed
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)

	status, err := service.EnterQueue(context.Background(), EnterQueueInput{
		AccountID:          "account_2",
		ProfileID:          "profile_2",
		DeviceSessionID:    "device_2",
		QueueType:          "casual",
		MatchFormatID:      "1v1",
		ModeID:             "mode_classic",
		RuleSetID:          "rule_standard",
		PreferredMapPoolID: "map_classic_square",
	})
	if err != nil {
		t.Fatalf("EnterQueue returned error: %v", err)
	}
	if status.QueueState != "assigned" {
		t.Fatalf("expected assigned status for second 1v1 member, got %s", status.QueueState)
	}
	if len(db.assignmentsByID) != 1 {
		t.Fatalf("expected one assignment, got %d", len(db.assignmentsByID))
	}
	var assignment storage.Assignment
	for _, record := range db.assignmentsByID {
		assignment = record
	}
	if assignment.ExpectedMemberCount != 2 {
		t.Fatalf("expected 1v1 assignment member count 2, got %d", assignment.ExpectedMemberCount)
	}
	if len(db.membersByKey) != 2 {
		t.Fatalf("expected two assignment members, got %d", len(db.membersByKey))
	}
}

func TestEnterQueuePostgresFormsSingleAssignment(t *testing.T) {
	pool := openQueueTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetQueueSchema(t, ctx, pool)
	seedQueuedEntries(t, ctx, pool, []storage.QueueEntry{
		buildQueuedEntry("queue_a", "account_a", "profile_a"),
		buildQueuedEntry("queue_b", "account_b", "profile_b"),
		buildQueuedEntry("queue_c", "account_c", "profile_c"),
	})
	service := NewService(storage.NewQueueRepository(pool), storage.NewAssignmentRepository(pool), pool, 30*time.Second)

	status, err := service.EnterQueue(ctx, EnterQueueInput{
		AccountID:       "account_d",
		ProfileID:       "profile_d",
		DeviceSessionID: "device_d",
		QueueType:       "ranked",
		ModeID:          "ranked_mode",
		RuleSetID:       "rule_standard",
	})
	if err != nil {
		t.Fatalf("EnterQueue returned error: %v", err)
	}
	if status.QueueState != "assigned" {
		t.Fatalf("expected assigned status for triggering member, got %s", status.QueueState)
	}

	assertQueueAssignmentCounts(t, ctx, pool, 1, 4, 4)
}

func TestEnterQueuePostgresRollsBackPartialAssignmentOnMemberFailure(t *testing.T) {
	pool := openQueueTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetQueueSchema(t, ctx, pool)
	seedQueuedEntries(t, ctx, pool, []storage.QueueEntry{
		buildQueuedEntry("queue_a", "account_dup", "profile_a"),
		buildQueuedEntry("queue_b", "account_dup", "profile_b"),
		buildQueuedEntry("queue_c", "account_c", "profile_c"),
	})
	service := NewService(storage.NewQueueRepository(pool), storage.NewAssignmentRepository(pool), pool, 30*time.Second)

	_, err := service.EnterQueue(ctx, EnterQueueInput{
		AccountID:       "account_d",
		ProfileID:       "profile_d",
		DeviceSessionID: "device_d",
		QueueType:       "ranked",
		ModeID:          "ranked_mode",
		RuleSetID:       "rule_standard",
	})
	if err == nil {
		t.Fatal("expected duplicate assignment member to fail")
	}

	assertQueueAssignmentCounts(t, ctx, pool, 0, 0, 0)
	var queuedCount int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM matchmaking_queue_entries WHERE state = 'queued'`).Scan(&queuedCount); err != nil {
		t.Fatalf("count queued entries: %v", err)
	}
	if queuedCount != 4 {
		t.Fatalf("expected four queued entries after rollback, got %d", queuedCount)
	}
}

func TestQueueAndAssignmentDataIntegrityConstraints(t *testing.T) {
	pool := openQueueTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetQueueSchema(t, ctx, pool)

	queueRepo := storage.NewQueueRepository(pool)
	invalidQueue := buildQueuedEntry("queue_invalid_state", "account_invalid", "profile_invalid")
	invalidQueue.State = "teleported"
	err := queueRepo.Insert(ctx, invalidQueue)
	if !storage.IsConstraintViolation(err, "chk_matchmaking_queue_entries_state") {
		t.Fatalf("expected queue state check violation, got %v", err)
	}

	assignmentRepo := storage.NewAssignmentRepository(pool)
	now := time.Now().UTC()
	invalidAssignment := storage.Assignment{
		AssignmentID:           "assign_invalid_state",
		QueueKey:               BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		QueueType:              "ranked",
		SeasonID:               "season_s1",
		RoomID:                 "room_invalid",
		RoomKind:               "matchmade_room",
		MatchID:                "match_invalid",
		ModeID:                 "ranked_mode",
		RuleSetID:              "rule_standard",
		MapID:                  "map_classic_square",
		ServerHost:             "127.0.0.1",
		ServerPort:             9000,
		CaptainAccountID:       "account_invalid",
		AssignmentRevision:     1,
		ExpectedMemberCount:    4,
		State:                  "teleported",
		CaptainDeadlineUnixSec: now.Add(time.Minute).Unix(),
		CommitDeadlineUnixSec:  now.Add(5 * time.Minute).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
	}
	err = assignmentRepo.Insert(ctx, invalidAssignment)
	if !storage.IsConstraintViolation(err, "chk_matchmaking_assignments_state") {
		t.Fatalf("expected assignment state check violation, got %v", err)
	}

	invalidAssignment.AssignmentID = "assign_invalid_port"
	invalidAssignment.MatchID = "match_invalid_port"
	invalidAssignment.State = "assigned"
	invalidAssignment.ServerPort = 70000
	err = assignmentRepo.Insert(ctx, invalidAssignment)
	if !storage.IsConstraintViolation(err, "chk_matchmaking_assignments_server_port") {
		t.Fatalf("expected assignment server port check violation, got %v", err)
	}
}

func TestSelectRatingCompatibleCandidatesUsesWaitExpansion(t *testing.T) {
	now := time.Now().UTC().Unix()
	entries := []storage.QueueEntry{
		{QueueEntryID: "queue_a", RatingSnapshot: 1000, EnqueueUnixSec: now - 5},
		{QueueEntryID: "queue_b", RatingSnapshot: 1130, EnqueueUnixSec: now - 4},
		{QueueEntryID: "queue_c", RatingSnapshot: 1160, EnqueueUnixSec: now - 3},
		{QueueEntryID: "queue_d", RatingSnapshot: 1190, EnqueueUnixSec: now - 2},
		{QueueEntryID: "queue_e", RatingSnapshot: 1600, EnqueueUnixSec: now - 1},
	}

	selected := selectRatingCompatibleCandidates(entries, 4, now)
	if len(selected) != 0 {
		t.Fatalf("expected no compatible group before wait expansion, got %+v", selected)
	}

	entries[0].EnqueueUnixSec = now - 20
	selected = selectRatingCompatibleCandidates(entries, 4, now)
	if len(selected) != 4 {
		t.Fatalf("expected four compatible candidates after wait expansion, got %d", len(selected))
	}
	for _, entry := range selected {
		if entry.QueueEntryID == "queue_e" {
			t.Fatalf("expected far rating candidate to stay excluded: %+v", selected)
		}
	}
}

func openQueueTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := strings.TrimSpace(os.Getenv("GAME_TEST_POSTGRES_DSN"))
	if dsn == "" {
		t.Skip("GAME_TEST_POSTGRES_DSN is not set; skipping queue postgres integration tests")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("open pgx pool: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	lockQueueTestDatabase(t, pool)
	if err := applyQueueMigrations(context.Background(), pool); err != nil {
		t.Fatalf("apply migrations: %v", err)
	}
	return pool
}

func lockQueueTestDatabase(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire db lock connection: %v", err)
	}
	deadline := time.Now().Add(2 * time.Minute)
	for {
		var locked bool
		if err := conn.QueryRow(ctx, `SELECT pg_try_advisory_lock(240031013)`).Scan(&locked); err != nil {
			conn.Release()
			t.Fatalf("acquire db advisory lock: %v", err)
		}
		if locked {
			break
		}
		if time.Now().After(deadline) {
			conn.Release()
			t.Fatal("timed out waiting for db advisory lock")
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Cleanup(func() {
		_, _ = conn.Exec(context.Background(), `SELECT pg_advisory_unlock(240031013)`)
		conn.Release()
	})
}

func applyQueueMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	migrationDir := filepath.Join("..", "..", "migrations")
	entries, err := os.ReadDir(migrationDir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		sqlBytes, err := os.ReadFile(filepath.Join(migrationDir, entry.Name()))
		if err != nil {
			return err
		}
		if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
			return err
		}
	}
	return nil
}

func resetQueueSchema(t *testing.T, ctx context.Context, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(ctx, `
		TRUNCATE TABLE
			matchmaking_queue_entries,
			matchmaking_assignment_members,
			matchmaking_assignments
		CASCADE
	`)
	if err != nil {
		t.Fatalf("reset queue schema: %v", err)
	}
}

func seedQueuedEntries(t *testing.T, ctx context.Context, pool *pgxpool.Pool, entries []storage.QueueEntry) {
	t.Helper()
	repo := storage.NewQueueRepository(pool)
	for _, entry := range entries {
		if err := repo.Insert(ctx, entry); err != nil {
			t.Fatalf("seed queue entry %s: %v", entry.QueueEntryID, err)
		}
	}
}

func buildQueuedEntry(queueEntryID string, accountID string, profileID string) storage.QueueEntry {
	now := time.Now().UTC()
	return storage.QueueEntry{
		QueueEntryID:         queueEntryID,
		QueueType:            "ranked",
		QueueKey:             BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		SeasonID:             "season_s1",
		AccountID:            accountID,
		ProfileID:            profileID,
		DeviceSessionID:      "device_" + profileID,
		ModeID:               "ranked_mode",
		RuleSetID:            "rule_standard",
		RatingSnapshot:       1000,
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		State:                "queued",
		CreatedAt:            now,
		UpdatedAt:            now,
	}
}

func assertQueueAssignmentCounts(t *testing.T, ctx context.Context, pool *pgxpool.Pool, assignments int, members int, assignedQueues int) {
	t.Helper()
	countQueries := []struct {
		name string
		sql  string
		want int
	}{
		{name: "assignments", sql: `SELECT COUNT(*) FROM matchmaking_assignments`, want: assignments},
		{name: "assignment members", sql: `SELECT COUNT(*) FROM matchmaking_assignment_members`, want: members},
		{name: "assigned queue entries", sql: `SELECT COUNT(*) FROM matchmaking_queue_entries WHERE state = 'assigned'`, want: assignedQueues},
	}
	for _, query := range countQueries {
		var got int
		if err := pool.QueryRow(ctx, query.sql).Scan(&got); err != nil {
			t.Fatalf("count %s: %v", query.name, err)
		}
		if got != query.want {
			t.Fatalf("expected %s count %d, got %d", query.name, query.want, got)
		}
	}
}

func TestGetStatusReelectsCaptainAfterDeadline(t *testing.T) {
	db := newFakeQueueDB()
	now := time.Now().UTC()
	assignment := storage.Assignment{
		AssignmentID:           "assign_alpha",
		QueueKey:               BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		QueueType:              "ranked",
		SeasonID:               "season_s1",
		RoomID:                 "room_alpha",
		RoomKind:               "matchmade_room",
		MatchID:                "match_alpha",
		ModeID:                 "ranked_mode",
		RuleSetID:              "rule_standard",
		MapID:                  "map_classic_square",
		ServerHost:             "127.0.0.1",
		ServerPort:             9000,
		CaptainAccountID:       "account_a",
		AssignmentRevision:     1,
		ExpectedMemberCount:    4,
		State:                  "assigned",
		CaptainDeadlineUnixSec: now.Add(-time.Second).Unix(),
		CommitDeadlineUnixSec:  now.Add(time.Minute).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
	}
	db.assignmentsByID[assignment.AssignmentID] = assignment
	for idx, accountID := range []string{"account_a", "account_b", "account_c", "account_d"} {
		profileID := "profile_" + string(rune('a'+idx))
		entry := storage.QueueEntry{
			QueueEntryID:         "queue_" + string(rune('a'+idx)),
			QueueType:            "ranked",
			QueueKey:             assignment.QueueKey,
			SeasonID:             assignment.SeasonID,
			AccountID:            accountID,
			ProfileID:            profileID,
			DeviceSessionID:      "device_" + string(rune('a'+idx)),
			ModeID:               assignment.ModeID,
			RuleSetID:            assignment.RuleSetID,
			RatingSnapshot:       1000,
			EnqueueUnixSec:       now.Unix(),
			LastHeartbeatUnixSec: now.Unix(),
			State:                "assigned",
			AssignmentID:         assignment.AssignmentID,
			AssignmentRevision:   1,
			CreatedAt:            now,
			UpdatedAt:            now,
		}
		role := "join"
		if accountID == assignment.CaptainAccountID {
			role = "create"
		}
		member := storage.AssignmentMember{
			AssignmentID:   assignment.AssignmentID,
			AccountID:      accountID,
			ProfileID:      profileID,
			TicketRole:     role,
			AssignedTeamID: (idx % 2) + 1,
			RatingBefore:   1000,
			JoinState:      "assigned",
			CreatedAt:      now,
			UpdatedAt:      now,
		}
		db.entriesByID[entry.QueueEntryID] = entry
		db.entriesByProfile[entry.ProfileID] = entry
		db.membersByKey[member.AssignmentID+":"+member.AccountID] = member
	}

	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	status, err := service.GetStatus(context.Background(), "profile_b", "queue_b")
	if err != nil {
		t.Fatalf("GetStatus returned error: %v", err)
	}
	if status.AssignmentRevision != 2 {
		t.Fatalf("expected assignment revision 2 after reelect, got %d", status.AssignmentRevision)
	}
	if status.CaptainAccountID != "account_b" || status.TicketRole != "create" {
		t.Fatalf("expected account_b to become captain create, got captain=%s role=%s", status.CaptainAccountID, status.TicketRole)
	}
}

func TestGetStatusConvergesAllocationFailureToTerminalQueueState(t *testing.T) {
	db := newFakeQueueDB()
	now := time.Now().UTC()
	assignment := storage.Assignment{
		AssignmentID:           "assign_alloc_failed",
		QueueKey:               BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		QueueType:              "ranked",
		SeasonID:               "season_s1",
		RoomID:                 "room_alpha",
		RoomKind:               "matchmade_room",
		MatchID:                "match_alpha",
		ModeID:                 "ranked_mode",
		RuleSetID:              "rule_standard",
		MapID:                  "map_classic_square",
		ServerHost:             "127.0.0.1",
		ServerPort:             9000,
		BattleServerHost:       "10.1.1.8",
		BattleServerPort:       9200,
		CaptainAccountID:       "account_a",
		AssignmentRevision:     1,
		ExpectedMemberCount:    4,
		State:                  "assigned",
		AllocationState:        "alloc_failed",
		CommitDeadlineUnixSec:  now.Add(5 * time.Minute).Unix(),
		CaptainDeadlineUnixSec: now.Add(2 * time.Minute).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
	}
	entry := storage.QueueEntry{
		QueueEntryID:         "queue_alpha",
		QueueType:            "ranked",
		QueueKey:             assignment.QueueKey,
		SeasonID:             assignment.SeasonID,
		AccountID:            "account_a",
		ProfileID:            "profile_a",
		DeviceSessionID:      "device_a",
		ModeID:               assignment.ModeID,
		RuleSetID:            assignment.RuleSetID,
		RatingSnapshot:       1000,
		EnqueueUnixSec:       now.Unix(),
		LastHeartbeatUnixSec: now.Unix(),
		State:                "assigned",
		AssignmentID:         assignment.AssignmentID,
		AssignmentRevision:   assignment.AssignmentRevision,
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	member := storage.AssignmentMember{
		AssignmentID:   assignment.AssignmentID,
		AccountID:      "account_a",
		ProfileID:      "profile_a",
		TicketRole:     "create",
		AssignedTeamID: 1,
		JoinState:      "assigned",
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	db.assignmentsByID[assignment.AssignmentID] = assignment
	db.entriesByID[entry.QueueEntryID] = entry
	db.entriesByProfile[entry.ProfileID] = entry
	db.membersByKey[member.AssignmentID+":"+member.AccountID] = member

	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	status, err := service.GetStatus(context.Background(), "profile_a", "queue_alpha")
	if err != nil {
		t.Fatalf("GetStatus returned error: %v", err)
	}
	if status.QueueState != "failed" {
		t.Fatalf("expected terminal queue state failed, got %s", status.QueueState)
	}
	if status.QueuePhase != QueuePhaseCompleted || status.QueueTerminalReason != QueueTerminalReasonAllocationFailed {
		t.Fatalf("expected completed/allocation_failed canonical status, got phase=%s reason=%s", status.QueuePhase, status.QueueTerminalReason)
	}
	if status.QueueStatusText != "Battle allocation failed" {
		t.Fatalf("expected allocation failed status text, got %s", status.QueueStatusText)
	}
	if status.ServerHost != "" || status.ServerPort != 0 {
		t.Fatalf("expected endpoint hidden for failed terminal state, got %s:%d", status.ServerHost, status.ServerPort)
	}
	updated := db.entriesByID["queue_alpha"]
	if updated.State != "completed" || updated.CancelReason != "allocation_failed" {
		t.Fatalf("expected queue entry persisted as completed/allocation_failed, got state=%s reason=%s", updated.State, updated.CancelReason)
	}
}

func TestGetStatusConvergesHeartbeatTimeoutToTerminalQueueState(t *testing.T) {
	db := newFakeQueueDB()
	nowUnix := time.Now().UTC().Unix()
	entry := storage.QueueEntry{
		QueueEntryID:         "queue_heartbeat",
		QueueType:            "ranked",
		QueueKey:             BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		SeasonID:             "season_s1",
		AccountID:            "account_heartbeat",
		ProfileID:            "profile_heartbeat",
		DeviceSessionID:      "device_heartbeat",
		ModeID:               "ranked_mode",
		RuleSetID:            "rule_standard",
		RatingSnapshot:       1000,
		EnqueueUnixSec:       nowUnix - 100,
		LastHeartbeatUnixSec: nowUnix - 100,
		State:                QueuePhaseQueued,
		CreatedAt:            time.Unix(nowUnix-100, 0).UTC(),
		UpdatedAt:            time.Unix(nowUnix-100, 0).UTC(),
	}
	db.entriesByID[entry.QueueEntryID] = entry
	db.entriesByProfile[entry.ProfileID] = entry

	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	status, err := service.GetStatus(context.Background(), entry.ProfileID, entry.QueueEntryID)
	if err != nil {
		t.Fatalf("GetStatus returned error: %v", err)
	}
	if status.QueuePhase != QueuePhaseCompleted || status.QueueTerminalReason != QueueTerminalReasonHeartbeatTimeout {
		t.Fatalf("expected completed/heartbeat_timeout canonical status, got phase=%s reason=%s", status.QueuePhase, status.QueueTerminalReason)
	}
	if status.QueueState != "failed" {
		t.Fatalf("expected legacy queue_state failed, got %s", status.QueueState)
	}
	if status.QueueStatusText != "Queue heartbeat timeout" {
		t.Fatalf("expected heartbeat timeout status text, got %s", status.QueueStatusText)
	}

	updated := db.entriesByID[entry.QueueEntryID]
	if updated.State != QueuePhaseCompleted || updated.CancelReason != QueueTerminalReasonHeartbeatTimeout {
		t.Fatalf("expected persisted completed/heartbeat_timeout, got state=%s reason=%s", updated.State, updated.CancelReason)
	}
}

func TestAssignmentAllocationStateRetryTransition(t *testing.T) {
	db := newFakeQueueDB()
	now := time.Now().UTC()
	assignment := storage.Assignment{
		AssignmentID:           "assign_retry",
		QueueKey:               BuildQueueKey("ranked", "ranked_mode", "rule_standard"),
		QueueType:              "ranked",
		SeasonID:               "season_s1",
		RoomID:                 "room_alpha",
		RoomKind:               "matchmade_room",
		MatchID:                "match_alpha",
		ModeID:                 "ranked_mode",
		RuleSetID:              "rule_standard",
		MapID:                  "map_classic_square",
		ServerHost:             "127.0.0.1",
		ServerPort:             9000,
		CaptainAccountID:       "account_a",
		AssignmentRevision:     1,
		ExpectedMemberCount:    4,
		State:                  "assigned",
		AllocationState:        "allocating",
		CommitDeadlineUnixSec:  now.Add(5 * time.Minute).Unix(),
		CaptainDeadlineUnixSec: now.Add(2 * time.Minute).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
	}
	db.assignmentsByID[assignment.AssignmentID] = assignment
	repo := storage.NewAssignmentRepository(db)

	if err := repo.MarkAllocationFailed(context.Background(), assignment.AssignmentID, "battle_alpha", "MATCHMAKING_ALLOCATION_FAILED", "dial tcp timeout"); err != nil {
		t.Fatalf("MarkAllocationFailed returned error: %v", err)
	}
	failed := db.assignmentsByID[assignment.AssignmentID]
	if failed.AllocationState != "alloc_failed" {
		t.Fatalf("expected alloc_failed, got %s", failed.AllocationState)
	}
	if failed.AllocationErrorCode == "" || failed.AllocationLastError == "" {
		t.Fatalf("expected allocation failure context to be persisted")
	}

	if err := repo.UpdateAllocationState(context.Background(), assignment.AssignmentID, "allocated", "battle_alpha", "ds_001", "10.2.0.9", 9300); err != nil {
		t.Fatalf("UpdateAllocationState returned error: %v", err)
	}
	retried := db.assignmentsByID[assignment.AssignmentID]
	if retried.AllocationState != "allocated" {
		t.Fatalf("expected allocated after retry, got %s", retried.AllocationState)
	}
	if retried.AllocationErrorCode != "" || retried.AllocationLastError != "" {
		t.Fatalf("expected allocation error context to be cleared after retry success")
	}
	if retried.BattleServerHost != "10.2.0.9" || retried.BattleServerPort != 9300 {
		t.Fatalf("expected retry endpoint persisted, got %s:%d", retried.BattleServerHost, retried.BattleServerPort)
	}
}
