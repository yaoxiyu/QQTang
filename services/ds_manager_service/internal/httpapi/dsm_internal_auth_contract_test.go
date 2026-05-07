package httpapi

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/shared/internalauth"
	"qqtang/services/ds_manager_service/internal/process"
)

func TestDSMInternalRoutesRejectMissingOrInvalidSignature(t *testing.T) {
	t.Parallel()

	router := newDSMTestRouter(t)
	cases := []struct {
		name string
		path string
		body []byte
	}{
		{name: "allocate", path: "/internal/v1/battles/allocate", body: []byte(`{"battle_id":"battle_a"}`)},
		{name: "ready", path: "/internal/v1/battles/battle_a/ready", body: []byte(`{}`)},
		{name: "active", path: "/internal/v1/battles/battle_a/active", body: []byte(`{}`)},
		{name: "reap", path: "/internal/v1/battles/battle_a/reap", body: []byte(`{}`)},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name+"/missing", func(t *testing.T) {
			resp := sendSignedDSMRequest(t, router, tc.path, tc.body, "", "")
			if resp.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401 for missing signature at %s, got %d body=%s", tc.path, resp.Code, resp.Body.String())
			}
		})

		t.Run(tc.name+"/invalid", func(t *testing.T) {
			resp := sendSignedDSMRequest(t, router, tc.path, tc.body, "primary", "wrong-secret")
			if resp.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401 for invalid signature at %s, got %d body=%s", tc.path, resp.Code, resp.Body.String())
			}
		})
	}
}

func TestDSMInternalRoutesAcceptSignedRequests(t *testing.T) {
	t.Parallel()

	router := newDSMTestRouter(t)
	cases := []struct {
		name string
		path string
		body []byte
	}{
		{name: "allocate", path: "/internal/v1/battles/allocate", body: []byte(`{"battle_id":"battle_a"}`)},
		{name: "ready", path: "/internal/v1/battles/battle_a/ready", body: []byte(`{}`)},
		{name: "active", path: "/internal/v1/battles/battle_a/active", body: []byte(`{}`)},
		{name: "reap", path: "/internal/v1/battles/battle_a/reap", body: []byte(`{}`)},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			resp := sendSignedDSMRequest(t, router, tc.path, tc.body, "primary", "internal-secret")
			if resp.Code == http.StatusUnauthorized {
				t.Fatalf("expected signed request accepted at %s, got 401 body=%s", tc.path, resp.Body.String())
			}
		})
	}
}

func newDSMTestRouter(t *testing.T) http.Handler {
	t.Helper()

	alloc := allocator.New(19010, 19050, "127.0.0.1")
	runner := process.NewGodotProcessRunner(process.RunnerConfig{
		GodotExecutable:    "__missing_godot__",
		BattleScenePath:    "res://scenes/network/dedicated_server_scene.tscn",
		BattleTicketSecret: "test-ticket-secret",
	})

	return NewRouter(RouterDeps{
		Allocator:       alloc,
		ProcessRunner:   runner,
		InternalAuth:    auth.NewInternalAuth("primary", "internal-secret", time.Minute),
		AllocateHandler: NewAllocateHandler(alloc, runner),
		ReadyHandler:    NewReadyHandler(alloc),
		ActiveHandler:   NewActiveHandler(alloc),
		ReapHandler:     NewReapHandler(alloc, runner),
	})
}

func sendSignedDSMRequest(t *testing.T, router http.Handler, path string, body []byte, keyID string, secret string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	if keyID != "" && secret != "" {
		if err := internalauth.SignRequest(req, keyID, secret, body, time.Now().UTC()); err != nil {
			t.Fatalf("sign request: %v", err)
		}
	}
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)
	return resp
}
