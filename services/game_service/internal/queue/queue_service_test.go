package queue

import (
	"context"
	"reflect"
	"sort"
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
	assignmentsByID  map[string]storage.Assignment
	membersByKey     map[string]storage.AssignmentMember
}

func newFakeQueueDB() *fakeQueueDB {
	return &fakeQueueDB{
		entriesByProfile: map[string]storage.QueueEntry{},
		entriesByID:      map[string]storage.QueueEntry{},
		assignmentsByID:  map[string]storage.Assignment{},
		membersByKey:     map[string]storage.AssignmentMember{},
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
		}
		db.assignmentsByID[assignment.AssignmentID] = assignment
	case strings.Contains(sql, "INSERT INTO matchmaking_assignment_members"):
		member := storage.AssignmentMember{
			AssignmentID:   arguments[0].(string),
			AccountID:      arguments[1].(string),
			ProfileID:      arguments[2].(string),
			TicketRole:     arguments[3].(string),
			AssignedTeamID: arguments[4].(int),
			RatingBefore:   arguments[5].(int),
			JoinState:      arguments[6].(string),
			ResultState:    arguments[7].(string),
			CreatedAt:      arguments[8].(time.Time),
			UpdatedAt:      arguments[9].(time.Time),
		}
		db.membersByKey[member.AssignmentID+":"+member.AccountID] = member
	case strings.Contains(sql, "UPDATE matchmaking_queue_entries") && strings.Contains(sql, "cancel_reason"):
		entry := db.entriesByID[arguments[0].(string)]
		entry.State = arguments[1].(string)
		entry.CancelReason = arguments[2].(string)
		entry.AssignmentID = arguments[3].(string)
		entry.AssignmentRevision = arguments[4].(int)
		entry.LastHeartbeatUnixSec = arguments[5].(int64)
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
	case strings.Contains(sql, "UPDATE matchmaking_assignments"):
		assignment := db.assignmentsByID[arguments[0].(string)]
		assignment.CaptainAccountID = arguments[1].(string)
		assignment.AssignmentRevision = arguments[2].(int)
		assignment.CaptainDeadlineUnixSec = arguments[3].(int64)
		db.assignmentsByID[assignment.AssignmentID] = assignment
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
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), 30*time.Second)
	service.ConfigureAssignmentDefaults("10.0.0.2", 9100, 20, 60)

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

	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), 30*time.Second)
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
