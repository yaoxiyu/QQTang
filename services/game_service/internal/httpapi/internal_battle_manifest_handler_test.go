package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/storage"
)

type fakeManifestRow struct {
	values []any
	err    error
}

func (r fakeManifestRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for i := range dest {
		reflect.ValueOf(dest[i]).Elem().Set(reflect.ValueOf(r.values[i]))
	}
	return nil
}

type fakeManifestRows struct {
	values [][]any
	index  int
}

func (r *fakeManifestRows) Close() {}

func (r *fakeManifestRows) Err() error { return nil }

func (r *fakeManifestRows) CommandTag() pgconn.CommandTag { return pgconn.NewCommandTag("SELECT") }

func (r *fakeManifestRows) FieldDescriptions() []pgconn.FieldDescription { return nil }

func (r *fakeManifestRows) Next() bool {
	if r.index >= len(r.values) {
		return false
	}
	r.index++
	return true
}

func (r *fakeManifestRows) Scan(dest ...any) error {
	current := r.values[r.index-1]
	for i := range dest {
		reflect.ValueOf(dest[i]).Elem().Set(reflect.ValueOf(current[i]))
	}
	return nil
}

func (r *fakeManifestRows) Values() ([]any, error) {
	if r.index <= 0 || r.index > len(r.values) {
		return nil, nil
	}
	return r.values[r.index-1], nil
}

func (r *fakeManifestRows) RawValues() [][]byte { return nil }

func (r *fakeManifestRows) Conn() *pgx.Conn { return nil }

type fakeManifestDB struct {
	assignmentsByID    map[string]storage.Assignment
	battleByBattleID   map[string]storage.BattleInstance
	membersByAssignID  map[string][]storage.AssignmentMember
}

func newFakeManifestDB() *fakeManifestDB {
	return &fakeManifestDB{
		assignmentsByID:   map[string]storage.Assignment{},
		battleByBattleID:  map[string]storage.BattleInstance{},
		membersByAssignID: map[string][]storage.AssignmentMember{},
	}
}

func (db *fakeManifestDB) Exec(_ context.Context, _ string, _ ...any) (pgconn.CommandTag, error) {
	return pgconn.NewCommandTag("OK"), nil
}

func (db *fakeManifestDB) Query(_ context.Context, sql string, args ...any) (pgx.Rows, error) {
	if strings.Contains(sql, "FROM matchmaking_assignment_members") {
		assignmentID := args[0].(string)
		rows := &fakeManifestRows{}
		for _, m := range db.membersByAssignID[assignmentID] {
			rows.values = append(rows.values, []any{
				m.AssignmentID,
				m.AccountID,
				m.ProfileID,
				m.TicketRole,
				m.AssignedTeamID,
				m.RatingBefore,
				m.JoinState,
				m.ResultState,
				m.CreatedAt,
				m.UpdatedAt,
				m.SourceRoomID,
				m.SourceRoomMemberID,
				m.BattleJoinState,
				m.RoomReturnState,
			})
		}
		return rows, nil
	}
	return &fakeManifestRows{}, nil
}

func (db *fakeManifestDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "FROM battle_instances"):
		battleID := args[0].(string)
		bi, ok := db.battleByBattleID[battleID]
		if !ok {
			return fakeManifestRow{err: pgx.ErrNoRows}
		}
		return fakeManifestRow{values: []any{
			bi.BattleID,
			bi.AssignmentID,
			bi.MatchID,
			bi.DSInstanceID,
			bi.ServerHost,
			bi.ServerPort,
			bi.State,
			bi.StartedAt,
			bi.ReadyAt,
			bi.FinishedAt,
			bi.FinalizedAt,
			bi.ReapedAt,
			bi.CreatedAt,
			bi.UpdatedAt,
		}}
	case strings.Contains(sql, "FROM matchmaking_assignments"):
		assignmentID := args[0].(string)
		a, ok := db.assignmentsByID[assignmentID]
		if !ok {
			return fakeManifestRow{err: pgx.ErrNoRows}
		}
		return fakeManifestRow{values: []any{
			a.AssignmentID,
			a.QueueKey,
			a.QueueType,
			a.SeasonID,
			a.RoomID,
			a.RoomKind,
			a.MatchID,
			a.ModeID,
			a.RuleSetID,
			a.MapID,
			a.ServerHost,
			a.ServerPort,
			a.CaptainAccountID,
			a.AssignmentRevision,
			a.ExpectedMemberCount,
			a.State,
			a.CaptainDeadlineUnixSec,
			a.CommitDeadlineUnixSec,
			a.FinalizedAt,
			a.CreatedAt,
			a.UpdatedAt,
			a.SourceRoomID,
			a.SourceRoomKind,
			a.BattleID,
			a.DSInstanceID,
			a.BattleServerHost,
			a.BattleServerPort,
			a.AllocationState,
			a.AllocationErrorCode,
			a.AllocationLastError,
			a.RoomReturnPolicy,
			a.AllocationStartedAt,
			a.BattleReadyAt,
			a.BattleFinishedAt,
			a.ReturnCompletedAt,
		}}
	default:
		return fakeManifestRow{err: pgx.ErrNoRows}
	}
}

func TestInternalBattleManifestRejectsMissingInternalAuth(t *testing.T) {
	handler := buildSignedManifestHandlerWithSeededDB(t, "allocated")
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/battles/battle_1/manifest", nil)
	req.SetPathValue("battle_id", "battle_1")
	resp := httptest.NewRecorder()

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing internal auth, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func TestInternalBattleManifestReturnsManifestForSignedRequest(t *testing.T) {
	handler := buildSignedManifestHandlerWithSeededDB(t, "allocated")
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/battles/battle_1/manifest", nil)
	req.SetPathValue("battle_id", "battle_1")
	signInternalHTTPTestRequest(t, req, []byte{}, "primary", "internal_secret", time.Now().UTC())
	resp := httptest.NewRecorder()

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 for signed manifest request, got %d body=%s", resp.Code, resp.Body.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	assertManifestField(t, payload, "assignment_id", "assign_1")
	assertManifestField(t, payload, "battle_id", "battle_1")
	assertManifestField(t, payload, "match_id", "match_1")
	assertManifestField(t, payload, "map_id", "map_alpha")
	assertManifestField(t, payload, "rule_set_id", "ruleset_standard")
	assertManifestField(t, payload, "mode_id", "mode_classic")
	assertManifestField(t, payload, "expected_member_count", float64(2))

	if _, ok := payload["allocation_error_code"]; ok {
		t.Fatalf("manifest must not leak allocation_error_code")
	}
	if _, ok := payload["allocation_last_error"]; ok {
		t.Fatalf("manifest must not leak allocation_last_error")
	}
	if _, ok := payload["captain_account_id"]; ok {
		t.Fatalf("manifest must not leak captain_account_id")
	}

	members, ok := payload["members"].([]any)
	if !ok || len(members) != 2 {
		t.Fatalf("expected 2 members in manifest response, got %+v", payload["members"])
	}
	first, ok := members[0].(map[string]any)
	if !ok {
		t.Fatalf("expected first member object, got %T", members[0])
	}
	assertManifestField(t, first, "account_id", "acc_1")
	assertManifestField(t, first, "profile_id", "pro_1")
	assertManifestField(t, first, "assigned_team_id", float64(1))
}

func TestInternalBattleManifestRejectsInvalidAssignmentState(t *testing.T) {
	handler := buildSignedManifestHandlerWithSeededDB(t, "alloc_failed")
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/battles/battle_1/manifest", nil)
	req.SetPathValue("battle_id", "battle_1")
	signInternalHTTPTestRequest(t, req, []byte{}, "primary", "internal_secret", time.Now().UTC())
	resp := httptest.NewRecorder()

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusConflict {
		t.Fatalf("expected 409 for invalid assignment allocation state, got %d body=%s", resp.Code, resp.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode error response: %v", err)
	}
	assertManifestField(t, payload, "error_code", "ASSIGNMENT_STATE_INVALID")
}

func buildSignedManifestHandlerWithSeededDB(t *testing.T, allocationState string) http.Handler {
	t.Helper()
	now := time.Now().UTC()
	db := newFakeManifestDB()
	db.battleByBattleID["battle_1"] = storage.BattleInstance{
		BattleID:     "battle_1",
		AssignmentID: "assign_1",
		MatchID:      "match_1",
		State:        "starting",
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	db.assignmentsByID["assign_1"] = storage.Assignment{
		AssignmentID:        "assign_1",
		QueueKey:            "casual:mode_classic:ruleset_standard:2v2",
		QueueType:           "casual",
		SeasonID:            "s1",
		RoomID:              "room_1",
		RoomKind:            "custom_room",
		MatchID:             "match_1",
		ModeID:              "mode_classic",
		RuleSetID:           "ruleset_standard",
		MapID:               "map_alpha",
		AssignmentRevision:  1,
		ExpectedMemberCount: 2,
		State:               "assigned",
		CreatedAt:           now,
		UpdatedAt:           now,
		AllocationState:     allocationState,
		BattleID:            "battle_1",
	}
	db.membersByAssignID["assign_1"] = []storage.AssignmentMember{
		{
			AssignmentID:   "assign_1",
			AccountID:      "acc_1",
			ProfileID:      "pro_1",
			AssignedTeamID: 1,
			CreatedAt:      now,
			UpdatedAt:      now,
		},
		{
			AssignmentID:   "assign_1",
			AccountID:      "acc_2",
			ProfileID:      "pro_2",
			AssignedTeamID: 2,
			CreatedAt:      now.Add(time.Second),
			UpdatedAt:      now.Add(time.Second),
		},
	}

	service := battlealloc.NewService(
		storage.NewAssignmentRepository(db),
		storage.NewBattleInstanceRepository(db),
		"http://unused",
		"primary",
		"internal_secret",
	)
	manifestHandler := NewInternalBattleManifestHandler(service)
	internalAuth := auth.NewInternalAuth("primary", "internal_secret", time.Minute)
	return withInternalAuth(internalAuth, http.HandlerFunc(manifestHandler.GetManifest))
}

func assertManifestField(t *testing.T, payload map[string]any, key string, want any) {
	t.Helper()
	got, ok := payload[key]
	if !ok {
		t.Fatalf("missing field %s in payload: %+v", key, payload)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected %s: want=%v got=%v", key, want, got)
	}
}
