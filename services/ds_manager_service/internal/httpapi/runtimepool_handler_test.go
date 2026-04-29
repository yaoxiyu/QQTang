package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/internalhttp"
	"qqtang/services/ds_manager_service/internal/runtimepool"
)

func TestRuntimePoolHandlersAllocateStatusReadyActiveReap(t *testing.T) {
	pool := runtimepool.NewFakePool("qqt-ds-slot-001", 9000)
	router := NewRouter(RouterDeps{
		InternalAuth:    auth.NewInternalAuth("primary", "internal-secret", time.Minute),
		AllocateHandler: NewRuntimePoolAllocateHandler(pool),
		ReadyHandler:    NewRuntimePoolReadyHandler(pool),
		ActiveHandler:   NewRuntimePoolActiveHandler(pool),
		ReapHandler:     NewRuntimePoolReapHandler(pool),
		StatusHandler:   NewStatusHandler(pool),
	})

	allocateBody := []byte(`{"battle_id":"battle-1","assignment_id":"assign-1","match_id":"match-1","wait_ready":true,"idempotency_key":"assign-1:battle-1"}`)
	allocateResp := sendSignedDSMRequestWithMethod(t, router, http.MethodPost, "/internal/v1/battles/allocate", allocateBody, "primary", "internal-secret")
	if allocateResp.Code != http.StatusOK {
		t.Fatalf("allocate status = %d body=%s", allocateResp.Code, allocateResp.Body.String())
	}
	assertDSMJSONField(t, allocateResp.Body.Bytes(), "allocation_state", "ready")
	assertDSMJSONField(t, allocateResp.Body.Bytes(), "server_host", "qqt-ds-slot-001")

	statusResp := sendSignedDSMRequestWithMethod(t, router, http.MethodGet, "/internal/v1/battles/battle-1", nil, "primary", "internal-secret")
	if statusResp.Code != http.StatusOK {
		t.Fatalf("status code = %d body=%s", statusResp.Code, statusResp.Body.String())
	}
	assertDSMJSONField(t, statusResp.Body.Bytes(), "lease_id", "fake_lease_battle-1")

	activeResp := sendSignedDSMRequestWithMethod(t, router, http.MethodPost, "/internal/v1/battles/battle-1/active", []byte(`{}`), "primary", "internal-secret")
	if activeResp.Code != http.StatusOK {
		t.Fatalf("active status = %d body=%s", activeResp.Code, activeResp.Body.String())
	}

	reapResp := sendSignedDSMRequestWithMethod(t, router, http.MethodPost, "/internal/v1/battles/battle-1/reap", []byte(`{}`), "primary", "internal-secret")
	if reapResp.Code != http.StatusOK {
		t.Fatalf("reap status = %d body=%s", reapResp.Code, reapResp.Body.String())
	}
}

func sendSignedDSMRequestWithMethod(t *testing.T, router http.Handler, method string, path string, body []byte, keyID string, secret string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	if keyID != "" && secret != "" {
		if err := internalhttp.SignRequest(req, keyID, secret, body, time.Now().UTC()); err != nil {
			t.Fatalf("sign request: %v", err)
		}
	}
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)
	return resp
}

func assertDSMJSONField(t *testing.T, body []byte, field string, expected string) {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("json parse failed: %v body=%s", err, string(body))
	}
	if got := payload[field]; got != expected {
		t.Fatalf("%s = %v, want %s; body=%s", field, got, expected, string(body))
	}
}
