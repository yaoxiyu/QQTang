package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/finalize"
	"qqtang/services/game_service/internal/internalhttp"
)

type stubFinalizeService struct {
	result finalize.FinalizeResult
	err    error
	last   finalize.FinalizeInput
}

func (s *stubFinalizeService) Finalize(_ context.Context, input finalize.FinalizeInput) (finalize.FinalizeResult, error) {
	s.last = input
	if s.err != nil {
		return finalize.FinalizeResult{}, s.err
	}
	return s.result, nil
}

var finalizeNonceSeq atomic.Int64

func TestInternalFinalizeRejectsMissingSignature(t *testing.T) {
	handler := buildInternalFinalizeHandler(&stubFinalizeService{})
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/matches/finalize", bytes.NewReader(mustFinalizeRequestJSON(t)))
	resp := httptest.NewRecorder()

	handler.ServeHTTP(resp, req)
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing signature, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func TestInternalFinalizeSuccessIncludesExpectedFields(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	service := &stubFinalizeService{
		result: finalize.FinalizeResult{
			FinalizeState:    "committed",
			MatchID:          "match_1",
			AssignmentID:     "assign_1",
			AlreadyCommitted: false,
			ResultHash:       "sha256:abc",
			SettlementSummary: finalize.SettlementSummary{
				ProfileCount:     2,
				SeasonPointTotal: 10,
				CareerXPTotal:    200,
				SoftGoldTotal:    300,
			},
			FinalizedAt: now,
		},
	}
	handler := buildInternalFinalizeHandler(service)
	resp := postSignedFinalize(t, handler, mustFinalizeRequestJSON(t))
	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 finalize success, got %d body=%s", resp.Code, resp.Body.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	assertFinalizeField(t, payload, "ok", true)
	assertFinalizeField(t, payload, "finalize_state", "committed")
	assertFinalizeField(t, payload, "match_id", "match_1")
	assertFinalizeField(t, payload, "assignment_id", "assign_1")
	assertFinalizeField(t, payload, "already_committed", false)
	assertFinalizeField(t, payload, "result_hash", "sha256:abc")

	summary, ok := payload["settlement_summary"].(map[string]any)
	if !ok {
		t.Fatalf("expected settlement_summary object, got %T", payload["settlement_summary"])
	}
	assertFinalizeField(t, summary, "profile_count", float64(2))
	assertFinalizeField(t, summary, "season_point_total", float64(10))
	assertFinalizeField(t, summary, "career_xp_total", float64(200))
	assertFinalizeField(t, summary, "soft_gold_total", float64(300))

	if _, ok := payload["finalized_at"]; !ok {
		t.Fatalf("expected finalized_at in response payload")
	}
	if service.last.AssignmentID != "assign_1" || service.last.MatchID != "match_1" {
		t.Fatalf("handler did not pass expected finalize input: %+v", service.last)
	}
}

func TestInternalFinalizeIdempotentResponse(t *testing.T) {
	service := &stubFinalizeService{
		result: finalize.FinalizeResult{
			FinalizeState:    "committed",
			MatchID:          "match_1",
			AssignmentID:     "assign_1",
			AlreadyCommitted: true,
			ResultHash:       "sha256:stable",
			SettlementSummary: finalize.SettlementSummary{
				ProfileCount: 2,
			},
			FinalizedAt: time.Now().UTC(),
		},
	}
	handler := buildInternalFinalizeHandler(service)
	resp := postSignedFinalize(t, handler, mustFinalizeRequestJSON(t))
	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 for idempotent finalize, got %d body=%s", resp.Code, resp.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode idempotent response: %v", err)
	}
	assertFinalizeField(t, payload, "already_committed", true)
}

func TestInternalFinalizeRejectsHashMismatch(t *testing.T) {
	service := &stubFinalizeService{err: finalize.ErrFinalizeHashMismatch}
	handler := buildInternalFinalizeHandler(service)
	resp := postSignedFinalize(t, handler, mustFinalizeRequestJSON(t))
	if resp.Code != http.StatusConflict {
		t.Fatalf("expected 409 for hash mismatch, got %d body=%s", resp.Code, resp.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode hash mismatch response: %v", err)
	}
	assertFinalizeField(t, payload, "error_code", "MATCH_FINALIZE_HASH_MISMATCH")
}

func TestInternalFinalizeRejectsSettlementIntegrityViolation(t *testing.T) {
	service := &stubFinalizeService{err: finalize.ErrFinalizeMemberResultInvalid}
	handler := buildInternalFinalizeHandler(service)
	resp := postSignedFinalize(t, handler, mustFinalizeRequestJSON(t))
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for member result invalid, got %d body=%s", resp.Code, resp.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode invalid member result response: %v", err)
	}
	assertFinalizeField(t, payload, "error_code", "MATCH_FINALIZE_MEMBER_RESULT_INVALID")
}

func buildInternalFinalizeHandler(service finalizeExecutor) http.Handler {
	internalAuth := auth.NewInternalAuth("primary", "internal_secret", time.Minute)
	h := &InternalFinalizeHandler{service: service}
	return withInternalAuth(internalAuth, http.HandlerFunc(h.Finalize))
}

func postSignedFinalize(t *testing.T, handler http.Handler, body []byte) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/matches/finalize", bytes.NewReader(body))
	now := time.Now().UTC()
	ts := strconv.FormatInt(now.Unix(), 10)
	nonce := "nonce-" + strconv.FormatInt(finalizeNonceSeq.Add(1), 10)
	hash := internalhttp.BodySHA256Hex(body)
	sig := internalhttp.Sign(req.Method, req.URL.RequestURI(), ts, nonce, hash, "internal_secret")
	req.Header.Set(internalhttp.HeaderKeyID, "primary")
	req.Header.Set(internalhttp.HeaderTimestamp, ts)
	req.Header.Set(internalhttp.HeaderNonce, nonce)
	req.Header.Set(internalhttp.HeaderBodySHA256, hash)
	req.Header.Set(internalhttp.HeaderSignature, sig)
	resp := httptest.NewRecorder()
	handler.ServeHTTP(resp, req)
	return resp
}

func mustFinalizeRequestJSON(t *testing.T) []byte {
	t.Helper()
	finished := time.Now().UTC().Truncate(time.Second)
	started := finished.Add(-2 * time.Minute)
	payload := map[string]any{
		"match_id":      "match_1",
		"assignment_id": "assign_1",
		"room_id":       "room_1",
		"room_kind":     "matchmade_room",
		"season_id":     "s1",
		"mode_id":       "mode_1",
		"rule_set_id":   "rule_1",
		"map_id":        "map_1",
		"started_at":    started.Format(time.RFC3339Nano),
		"finished_at":   finished.Format(time.RFC3339Nano),
		"finish_reason": "normal",
		"score_policy":  "classic",
		"winner_team_ids": []int{
			1,
		},
		"winner_peer_ids": []int{
			1,
		},
		"result_hash": "sha256:abc",
		"member_results": []map[string]any{
			{
				"account_id":   "acc_1",
				"profile_id":   "pro_1",
				"team_id":      1,
				"peer_id":      1,
				"outcome":      "win",
				"player_score": 10,
				"team_score":   20,
				"placement":    1,
			},
		},
	}
	b, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal finalize payload: %v", err)
	}
	return b
}

func assertFinalizeField(t *testing.T, payload map[string]any, key string, want any) {
	t.Helper()
	got, ok := payload[key]
	if !ok {
		t.Fatalf("missing field %s in payload: %+v", key, payload)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected %s: want=%v got=%v", key, want, got)
	}
}
