package httpapi

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	assignmentpkg "qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/career"
	"qqtang/services/game_service/internal/finalize"
	"qqtang/services/shared/internalauth"
	"qqtang/services/shared/httpx"
	"qqtang/services/game_service/internal/queue"
	"qqtang/services/game_service/internal/storage"
)

type fakeHTTPRow struct {
	values []any
	err    error
}

func (r fakeHTTPRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for idx := range dest {
		reflect.ValueOf(dest[idx]).Elem().Set(reflect.ValueOf(r.values[idx]))
	}
	return nil
}

type fakeHTTPQueueDB struct {
	entriesByProfile map[string]storage.QueueEntry
	entriesByID      map[string]storage.QueueEntry
}

func newFakeHTTPQueueDB() *fakeHTTPQueueDB {
	return &fakeHTTPQueueDB{
		entriesByProfile: map[string]storage.QueueEntry{},
		entriesByID:      map[string]storage.QueueEntry{},
	}
}

func (db *fakeHTTPQueueDB) Exec(_ context.Context, sql string, arguments ...any) (pgconn.CommandTag, error) {
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
			TerminalReason:       arguments[16].(string),
			CancelReason:         arguments[17].(string),
			CreatedAt:            arguments[18].(time.Time),
			UpdatedAt:            arguments[19].(time.Time),
		}
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
	case strings.Contains(sql, "UPDATE matchmaking_queue_entries"):
		entry := db.entriesByID[arguments[0].(string)]
		entry.State = arguments[1].(string)
		entry.TerminalReason = arguments[2].(string)
		entry.CancelReason = arguments[2].(string)
		entry.AssignmentID = arguments[3].(string)
		entry.AssignmentRevision = arguments[4].(int)
		entry.LastHeartbeatUnixSec = arguments[5].(int64)
		db.entriesByProfile[entry.ProfileID] = entry
		db.entriesByID[entry.QueueEntryID] = entry
	}
	return pgconn.NewCommandTag("OK"), nil
}

func (db *fakeHTTPQueueDB) Query(_ context.Context, _ string, _ ...any) (pgx.Rows, error) {
	return nil, nil
}

func (db *fakeHTTPQueueDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "WHERE profile_id = $1"):
		entry, ok := db.entriesByProfile[args[0].(string)]
		if !ok || (entry.State != "queued" && entry.State != "assigned" && entry.State != "committing") {
			return fakeHTTPRow{err: pgx.ErrNoRows}
		}
		return fakeHTTPRow{values: queueEntryHTTPRow(entry)}
	case strings.Contains(sql, "WHERE queue_entry_id = $1"):
		entry, ok := db.entriesByID[args[0].(string)]
		if !ok {
			return fakeHTTPRow{err: pgx.ErrNoRows}
		}
		return fakeHTTPRow{values: queueEntryHTTPRow(entry)}
	default:
		return fakeHTTPRow{err: pgx.ErrNoRows}
	}
}

func queueEntryHTTPRow(entry storage.QueueEntry) []any {
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

func TestRouterMatchmakingEnterAndCancel(t *testing.T) {
	db := newFakeHTTPQueueDB()
	queueService := queue.NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	router := NewRouter(RouterDeps{
		SignedTokenAuth:            auth.NewSignedTokenAuth("test_secret"),
		InternalAuth:       auth.NewInternalAuth("primary", "internal_secret", time.Minute),
		MatchmakingHandler: NewMatchmakingHandler(queueService),
		CareerHandler:      NewCareerHandler((*career.Service)(nil)),
		SettlementHandler:  NewSettlementHandler((*finalize.Service)(nil)),
		InternalAssignmentHandler: NewInternalAssignmentHandler(
			assignmentpkg.NewService(storage.NewAssignmentRepository(db), time.Minute),
		),
		InternalFinalizeHandler: NewInternalFinalizeHandler((*finalize.Service)(nil)),
		ReadinessCheck:          func(context.Context) error { return nil },
	})

	token := signedAccessToken(t, "test_secret", auth.AccessTokenClaims{
		AccountID:        "account_1",
		ProfileID:        "profile_1",
		DeviceSessionID:  "device_1",
		ExpiresAtUnixSec: time.Now().UTC().Add(time.Hour).Unix(),
	})

	enterBody, _ := json.Marshal(map[string]any{
		"queue_type":      "ranked",
		"match_format_id": "1v1",
		"mode_id":         "ranked_mode",
		"rule_set_id":     "rule_standard",
		"selected_map_ids": []string{
			"map_classic_square",
		},
	})
	enterReq := httptest.NewRequest(http.MethodPost, "/api/v1/matchmaking/queue/enter", bytes.NewReader(enterBody))
	enterReq.Header.Set("Authorization", "Bearer "+token)
	enterResp := httptest.NewRecorder()
	router.ServeHTTP(enterResp, enterReq)
	if enterResp.Code != http.StatusOK {
		t.Fatalf("expected 200 on enter, got %d body=%s", enterResp.Code, enterResp.Body.String())
	}

	var enterPayload map[string]any
	if err := json.Unmarshal(enterResp.Body.Bytes(), &enterPayload); err != nil {
		t.Fatalf("failed to decode enter response: %v", err)
	}
	queueEntryID := enterPayload["queue_entry_id"].(string)
	if queueEntryID == "" {
		t.Fatal("expected queue_entry_id in enter response")
	}
	if got := enterPayload["queue_key"]; got != "ranked:ranked_mode:rule_standard:1v1" {
		t.Fatalf("expected 1v1 queue key, got %v", got)
	}
	if got := db.entriesByID[queueEntryID].PreferredMapPoolID; got != "map_classic_square" {
		t.Fatalf("expected selected map to be stored, got %s", got)
	}

	cancelBody, _ := json.Marshal(map[string]any{"queue_entry_id": queueEntryID})
	cancelReq := httptest.NewRequest(http.MethodPost, "/api/v1/matchmaking/queue/cancel", bytes.NewReader(cancelBody))
	cancelReq.Header.Set("Authorization", "Bearer "+token)
	cancelResp := httptest.NewRecorder()
	router.ServeHTTP(cancelResp, cancelReq)
	if cancelResp.Code != http.StatusOK {
		t.Fatalf("expected 200 on cancel, got %d body=%s", cancelResp.Code, cancelResp.Body.String())
	}
	if got := db.entriesByID[queueEntryID].State; got != "completed" {
		t.Fatalf("expected completed state in repository, got %s", got)
	}
}

func TestRouterMatchmakingCancelRejectsInvalidBody(t *testing.T) {
	db := newFakeHTTPQueueDB()
	queueService := queue.NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	router := NewRouter(RouterDeps{
		SignedTokenAuth:            auth.NewSignedTokenAuth("test_secret"),
		InternalAuth:       auth.NewInternalAuth("primary", "internal_secret", time.Minute),
		MatchmakingHandler: NewMatchmakingHandler(queueService),
		CareerHandler:      NewCareerHandler((*career.Service)(nil)),
		SettlementHandler:  NewSettlementHandler((*finalize.Service)(nil)),
		InternalAssignmentHandler: NewInternalAssignmentHandler(
			assignmentpkg.NewService(storage.NewAssignmentRepository(db), time.Minute),
		),
		InternalFinalizeHandler: NewInternalFinalizeHandler((*finalize.Service)(nil)),
		ReadinessCheck:          func(context.Context) error { return nil },
	})

	token := signedAccessToken(t, "test_secret", auth.AccessTokenClaims{
		AccountID:        "account_1",
		ProfileID:        "profile_1",
		DeviceSessionID:  "device_1",
		ExpiresAtUnixSec: time.Now().UTC().Add(time.Hour).Unix(),
	})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/matchmaking/queue/cancel", strings.NewReader(`{"queue_entry_id":`))
	req.Header.Set("Authorization", "Bearer "+token)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 on invalid cancel body, got %d body=%s", resp.Code, resp.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode error response: %v", err)
	}
	if payload["error_code"] != "REQUEST_INVALID_JSON" {
		t.Fatalf("expected REQUEST_INVALID_JSON, got %+v", payload)
	}
}

func TestInternalAuthMiddlewareAcceptsSignedRequest(t *testing.T) {
	body := []byte(`{"room_id":"room_a"}`)
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/assignments/assign_a/commit?x=1", bytes.NewReader(body))
	signInternalHTTPTestRequest(t, req, body, "primary", "internal_secret", time.Now())
	resp := httptest.NewRecorder()
	handler := withInternalAuth(auth.NewInternalAuth("primary", "internal_secret", time.Minute), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("handler could not read restored body: %v", err)
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
	}))

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 for signed request, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func TestInternalAuthMiddlewareRejectsMissingSignature(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/assignments/assign_a/grant", nil)
	resp := httptest.NewRecorder()
	handler := withInternalAuth(auth.NewInternalAuth("primary", "internal_secret", time.Minute), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler must not be called")
	}))

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing internal auth, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func TestInternalAuthMiddlewareRejectsLegacySharedSecretOnly(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/assignments/assign_a/grant", nil)
	req.Header.Set("X-Internal-Secret", "internal_secret")
	resp := httptest.NewRecorder()
	handler := withInternalAuth(auth.NewInternalAuth("primary", "internal_secret", time.Minute), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler must not be called")
	}))

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 when only X-Internal-Secret is provided, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func signedAccessToken(t *testing.T, secret string, claims auth.AccessTokenClaims) string {
	t.Helper()
	payload, err := json.Marshal(claims)
	if err != nil {
		t.Fatalf("marshal claims: %v", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(encoded))
	signature := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return encoded + "." + signature
}

func signInternalHTTPTestRequest(t *testing.T, req *http.Request, body []byte, keyID string, secret string, now time.Time) {
	t.Helper()
	timestamp := strconv.FormatInt(now.UTC().Unix(), 10)
	nonce := "nonce-" + timestamp
	bodyHash := internalauth.BodySHA256Hex(body)
	signature := internalauth.Sign(req.Method, req.URL.RequestURI(), timestamp, nonce, bodyHash, secret)
	req.Header.Set(internalauth.HeaderKeyID, keyID)
	req.Header.Set(internalauth.HeaderTimestamp, timestamp)
	req.Header.Set(internalauth.HeaderNonce, nonce)
	req.Header.Set(internalauth.HeaderBodySHA256, bodyHash)
	req.Header.Set(internalauth.HeaderSignature, signature)
}
