package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/internalhttp"
	"qqtang/services/game_service/internal/storage"
)

type fakeAssignmentCommitRow struct {
	values []any
	err    error
}

func (r fakeAssignmentCommitRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for i := range dest {
		reflect.ValueOf(dest[i]).Elem().Set(reflect.ValueOf(r.values[i]))
	}
	return nil
}

type fakeAssignmentCommitDB struct {
	assignments        map[string]storage.Assignment
	membersByKey       map[string]storage.AssignmentMember
	markCommittedCalls int
}

var assignmentCommitNonceSeq atomic.Int64

func newFakeAssignmentCommitDB() *fakeAssignmentCommitDB {
	return &fakeAssignmentCommitDB{
		assignments:  map[string]storage.Assignment{},
		membersByKey: map[string]storage.AssignmentMember{},
	}
}

func (db *fakeAssignmentCommitDB) Exec(_ context.Context, sql string, arguments ...any) (pgconn.CommandTag, error) {
	switch {
	case strings.Contains(sql, "UPDATE matchmaking_assignments") && strings.Contains(sql, "SET state = 'committed'"):
		assignmentID := arguments[0].(string)
		record, ok := db.assignments[assignmentID]
		if !ok {
			return pgconn.NewCommandTag("UPDATE 0"), nil
		}
		record.State = "committed"
		db.assignments[assignmentID] = record
		db.markCommittedCalls++
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "UPDATE matchmaking_assignment_members") && strings.Contains(sql, "join_state = 'room_committed'"):
		assignmentID := arguments[0].(string)
		accountID := arguments[1].(string)
		key := assignmentID + ":" + accountID
		member, ok := db.membersByKey[key]
		if !ok {
			return pgconn.NewCommandTag("UPDATE 0"), nil
		}
		member.JoinState = "room_committed"
		db.membersByKey[key] = member
		return pgconn.NewCommandTag("UPDATE 1"), nil
	default:
		return pgconn.NewCommandTag("OK"), nil
	}
}

func (db *fakeAssignmentCommitDB) Query(_ context.Context, _ string, _ ...any) (pgx.Rows, error) {
	return nil, nil
}

func (db *fakeAssignmentCommitDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "FROM matchmaking_assignments"):
		assignmentID := args[0].(string)
		record, ok := db.assignments[assignmentID]
		if !ok {
			return fakeAssignmentCommitRow{err: pgx.ErrNoRows}
		}
		return fakeAssignmentCommitRow{values: []any{
			record.AssignmentID,
			record.QueueKey,
			record.QueueType,
			record.SeasonID,
			record.RoomID,
			record.RoomKind,
			record.MatchID,
			record.ModeID,
			record.RuleSetID,
			record.MapID,
			record.ServerHost,
			record.ServerPort,
			record.CaptainAccountID,
			record.AssignmentRevision,
			record.ExpectedMemberCount,
			record.State,
			record.CaptainDeadlineUnixSec,
			record.CommitDeadlineUnixSec,
			record.FinalizedAt,
			record.CreatedAt,
			record.UpdatedAt,
			record.SourceRoomID,
			record.SourceRoomKind,
			record.BattleID,
			record.DSInstanceID,
			record.BattleServerHost,
			record.BattleServerPort,
			record.AllocationState,
			record.AllocationErrorCode,
			record.AllocationLastError,
			record.RoomReturnPolicy,
			record.AllocationStartedAt,
			record.BattleReadyAt,
			record.BattleFinishedAt,
			record.ReturnCompletedAt,
		}}
	case strings.Contains(sql, "FROM matchmaking_assignment_members"):
		assignmentID := args[0].(string)
		accountID := args[1].(string)
		member, ok := db.membersByKey[assignmentID+":"+accountID]
		if !ok {
			return fakeAssignmentCommitRow{err: pgx.ErrNoRows}
		}
		return fakeAssignmentCommitRow{values: []any{
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
			member.CharacterID,
			member.CharacterSkinID,
			member.BubbleStyleID,
			member.BubbleSkinID,
			member.SourceRoomID,
			member.SourceRoomMemberID,
			member.BattleJoinState,
			member.RoomReturnState,
		}}
	default:
		return fakeAssignmentCommitRow{err: pgx.ErrNoRows}
	}
}

func TestInternalAssignmentCommitRejectsMissingSignature(t *testing.T) {
	handler, _ := buildInternalAssignmentCommitHandler(t)
	body := []byte(`{"account_id":"acc_1","profile_id":"pro_1","assignment_revision":7,"room_id":"room_1"}`)
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/assignments/assign_1/commit", bytes.NewReader(body))
	resp := httptest.NewRecorder()

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing signature, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func TestInternalAssignmentCommitSuccessAndIdempotent(t *testing.T) {
	handler, db := buildInternalAssignmentCommitHandler(t)

	first := postSignedAssignmentCommit(t, handler, "assign_1", map[string]any{
		"account_id":          "acc_1",
		"profile_id":          "pro_1",
		"assignment_revision": 7,
		"room_id":             "room_1",
	})
	if first.Code != http.StatusOK {
		t.Fatalf("expected first commit 200, got %d body=%s", first.Code, first.Body.String())
	}
	var firstPayload map[string]any
	if err := json.Unmarshal(first.Body.Bytes(), &firstPayload); err != nil {
		t.Fatalf("decode first response: %v", err)
	}
	if firstPayload["commit_state"] != "committed" {
		t.Fatalf("expected commit_state committed, got %+v", firstPayload)
	}
	if db.assignments["assign_1"].State != "committed" {
		t.Fatalf("expected assignment state committed after first call, got %s", db.assignments["assign_1"].State)
	}
	if db.markCommittedCalls != 1 {
		t.Fatalf("expected MarkCommitted path called once, got %d", db.markCommittedCalls)
	}

	second := postSignedAssignmentCommit(t, handler, "assign_1", map[string]any{
		"account_id":          "acc_1",
		"profile_id":          "pro_1",
		"assignment_revision": 7,
		"room_id":             "room_1",
	})
	if second.Code != http.StatusOK {
		t.Fatalf("expected second commit 200 (idempotent), got %d body=%s", second.Code, second.Body.String())
	}
	if db.markCommittedCalls != 1 {
		t.Fatalf("expected no extra committed transition on idempotent call, got %d", db.markCommittedCalls)
	}
}

func TestInternalAssignmentCommitRejectsInvalidAssignmentRoomAndMember(t *testing.T) {
	handler, _ := buildInternalAssignmentCommitHandler(t)

	notFound := postSignedAssignmentCommit(t, handler, "assign_missing", map[string]any{
		"account_id":          "acc_1",
		"profile_id":          "pro_1",
		"assignment_revision": 7,
		"room_id":             "room_1",
	})
	if notFound.Code != http.StatusNotFound {
		t.Fatalf("expected 404 for missing assignment, got %d body=%s", notFound.Code, notFound.Body.String())
	}

	invalidRoom := postSignedAssignmentCommit(t, handler, "assign_1", map[string]any{
		"account_id":          "acc_1",
		"profile_id":          "pro_1",
		"assignment_revision": 7,
		"room_id":             "room_wrong",
	})
	if invalidRoom.Code != http.StatusConflict {
		t.Fatalf("expected 409 for invalid room_id, got %d body=%s", invalidRoom.Code, invalidRoom.Body.String())
	}

	invalidMember := postSignedAssignmentCommit(t, handler, "assign_1", map[string]any{
		"account_id":          "acc_missing",
		"profile_id":          "pro_missing",
		"assignment_revision": 7,
		"room_id":             "room_1",
	})
	if invalidMember.Code != http.StatusNotFound {
		t.Fatalf("expected 404 for invalid member, got %d body=%s", invalidMember.Code, invalidMember.Body.String())
	}
}

func buildInternalAssignmentCommitHandler(t *testing.T) (http.Handler, *fakeAssignmentCommitDB) {
	t.Helper()
	now := time.Now().UTC()
	db := newFakeAssignmentCommitDB()
	db.assignments["assign_1"] = storage.Assignment{
		AssignmentID:           "assign_1",
		QueueKey:               "casual:mode:rule:2v2",
		QueueType:              "casual",
		SeasonID:               "s1",
		RoomID:                 "room_1",
		RoomKind:               "ranked_match_room",
		MatchID:                "match_1",
		ModeID:                 "mode_1",
		RuleSetID:              "rule_1",
		MapID:                  "map_1",
		CaptainAccountID:       "acc_1",
		AssignmentRevision:     7,
		ExpectedMemberCount:    4,
		State:                  "ready_pending_ack",
		CaptainDeadlineUnixSec: now.Add(time.Minute).Unix(),
		CommitDeadlineUnixSec:  now.Add(5 * time.Minute).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
		AllocationState:        "battle_ready",
	}
	db.membersByKey["assign_1:acc_1"] = storage.AssignmentMember{
		AssignmentID:   "assign_1",
		AccountID:      "acc_1",
		ProfileID:      "pro_1",
		TicketRole:     "create",
		AssignedTeamID: 1,
		JoinState:      "ticket_granted",
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	service := assignment.NewService(storage.NewAssignmentRepository(db), time.Minute)
	handler := NewInternalAssignmentHandler(service)
	internalAuth := auth.NewInternalAuth("primary", "internal_secret", time.Minute)
	return withInternalAuth(internalAuth, http.HandlerFunc(handler.Commit)), db
}

func postSignedAssignmentCommit(t *testing.T, handler http.Handler, assignmentID string, payload map[string]any) *httptest.ResponseRecorder {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal commit payload: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/assignments/"+assignmentID+"/commit", bytes.NewReader(body))
	now := time.Now().UTC()
	ts := strconv.FormatInt(now.Unix(), 10)
	nonce := "nonce-" + strconv.FormatInt(assignmentCommitNonceSeq.Add(1), 10)
	bodyHash := internalhttp.BodySHA256Hex(body)
	signature := internalhttp.Sign(req.Method, req.URL.RequestURI(), ts, nonce, bodyHash, "internal_secret")
	req.Header.Set(internalhttp.HeaderKeyID, "primary")
	req.Header.Set(internalhttp.HeaderTimestamp, ts)
	req.Header.Set(internalhttp.HeaderNonce, nonce)
	req.Header.Set(internalhttp.HeaderBodySHA256, bodyHash)
	req.Header.Set(internalhttp.HeaderSignature, signature)
	resp := httptest.NewRecorder()
	handler.ServeHTTP(resp, req)
	return resp
}
