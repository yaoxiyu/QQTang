package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"qqtang/services/ds_agent/internal/auth"
	"qqtang/services/shared/internalauth"
	"qqtang/services/ds_agent/internal/runtime"
	"qqtang/services/ds_agent/internal/state"
)

func TestHealthzDoesNotRequireInternalAuth(t *testing.T) {
	router := newTestRouter()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestInternalEndpointsRequireAuth(t *testing.T) {
	router := newTestRouter()

	req := httptest.NewRequest(http.MethodGet, "/internal/v1/agent/state", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestAgentStateAssignResetFlow(t *testing.T) {
	router := newTestRouter()

	stateResp := doSignedRequest(t, router, http.MethodGet, "/internal/v1/agent/state", nil)
	if stateResp.Code != http.StatusOK {
		t.Fatalf("state status = %d body=%s", stateResp.Code, stateResp.Body.String())
	}
	assertJSONField(t, stateResp.Body.Bytes(), "state", "idle")

	assignBody := []byte(`{"lease_id":"lease-1","battle_id":"battle-1","assignment_id":"assign-1","match_id":"match-1"}`)
	assignResp := doSignedRequest(t, router, http.MethodPost, "/internal/v1/agent/assign", assignBody)
	if assignResp.Code != http.StatusOK {
		t.Fatalf("assign status = %d body=%s", assignResp.Code, assignResp.Body.String())
	}
	assertJSONField(t, assignResp.Body.Bytes(), "agent_state", "assigned_mock")

	duplicateResp := doSignedRequest(t, router, http.MethodPost, "/internal/v1/agent/assign", assignBody)
	if duplicateResp.Code != http.StatusConflict {
		t.Fatalf("duplicate assign status = %d body=%s", duplicateResp.Code, duplicateResp.Body.String())
	}

	resetResp := doSignedRequest(t, router, http.MethodPost, "/internal/v1/agent/reset", []byte(`{}`))
	if resetResp.Code != http.StatusOK {
		t.Fatalf("reset status = %d body=%s", resetResp.Code, resetResp.Body.String())
	}
	assertJSONField(t, resetResp.Body.Bytes(), "agent_state", "idle")
}

func TestAssignStartsRunnerWhenConfigured(t *testing.T) {
	runner := &fakeRunner{}
	router := NewRouter(RouterDeps{
		InternalAuth: auth.NewInternalAuth("primary", "test-secret", time.Minute),
		StateStore:   state.NewStore(9000),
		Runner:       runner,
	})

	assignBody := []byte(`{"lease_id":"lease-1","battle_id":"battle-1","assignment_id":"assign-1","match_id":"match-1","advertise_host":"qqt-ds-slot-001","advertise_port":9000,"game_service_base_url":"http://game_service:18081","dsm_base_url":"http://ds_manager_service:18090"}`)
	assignResp := doSignedRequest(t, router, http.MethodPost, "/internal/v1/agent/assign", assignBody)
	if assignResp.Code != http.StatusOK {
		t.Fatalf("assign status = %d body=%s", assignResp.Code, assignResp.Body.String())
	}
	assertJSONField(t, assignResp.Body.Bytes(), "agent_state", "godot_started")
	if !runner.started {
		t.Fatalf("expected runner to start")
	}
	if runner.spec.BattleID != "battle-1" || runner.spec.AdvertisePort != 9000 {
		t.Fatalf("unexpected runner spec: %+v", runner.spec)
	}

	resetResp := doSignedRequest(t, router, http.MethodPost, "/internal/v1/agent/reset", []byte(`{}`))
	if resetResp.Code != http.StatusOK {
		t.Fatalf("reset status = %d body=%s", resetResp.Code, resetResp.Body.String())
	}
	if !runner.stopped {
		t.Fatalf("expected runner to stop on reset")
	}
}

func newTestRouter() http.Handler {
	return NewRouter(RouterDeps{
		InternalAuth: auth.NewInternalAuth("primary", "test-secret", time.Minute),
		StateStore:   state.NewStore(9000),
	})
}

func doSignedRequest(t *testing.T, router http.Handler, method string, path string, body []byte) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if err := internalauth.SignRequest(req, "primary", "test-secret", body, time.Now().UTC()); err != nil {
		t.Fatalf("SignRequest failed: %v", err)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func assertJSONField(t *testing.T, body []byte, field string, expected string) {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("json parse failed: %v body=%s", err, string(body))
	}
	if got := payload[field]; got != expected {
		t.Fatalf("%s = %v, want %s; body=%s", field, got, expected, string(body))
	}
}

type fakeRunner struct {
	started bool
	stopped bool
	spec    runtime.StartSpec
}

func (r *fakeRunner) Start(_ context.Context, spec runtime.StartSpec) (runtime.ProcessInfo, error) {
	r.started = true
	r.spec = spec
	return runtime.ProcessInfo{PID: 123}, nil
}

func (r *fakeRunner) Stop() error {
	r.stopped = true
	return nil
}

func (r *fakeRunner) IsRunning() bool {
	return r.started && !r.stopped
}
