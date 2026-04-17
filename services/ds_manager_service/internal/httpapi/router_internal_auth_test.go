package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/internalhttp"
	"qqtang/services/ds_manager_service/internal/process"
)

func TestInternalRoutesRejectMissingOrInvalidAuth(t *testing.T) {
	t.Parallel()

	router := newTestRouter(t)
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
			resp := sendSignedRequest(t, router, tc.path, tc.body, "", "")
			if resp.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401 for missing auth at %s, got %d body=%s", tc.path, resp.Code, resp.Body.String())
			}
		})

		t.Run(tc.name+"/invalid", func(t *testing.T) {
			resp := sendSignedRequest(t, router, tc.path, tc.body, "primary", "wrong-secret")
			if resp.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401 for invalid auth at %s, got %d body=%s", tc.path, resp.Code, resp.Body.String())
			}
		})
	}
}

func TestInternalRoutesAllowSignedAuth(t *testing.T) {
	t.Parallel()

	router := newTestRouter(t)
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
			resp := sendSignedRequest(t, router, tc.path, tc.body, "primary", "internal-secret")
			if resp.Code == http.StatusUnauthorized {
				t.Fatalf("expected signed request to pass auth at %s, got 401 body=%s", tc.path, resp.Body.String())
			}
		})
	}
}

func TestInternalBattleLifecycleWithSignedAuth(t *testing.T) {
	executable := createNoopExecutable(t)

	alloc := allocator.New(19010, 19050, "127.0.0.1")
	runner := process.NewGodotProcessRunner(process.RunnerConfig{
		GodotExecutable:    executable,
		BattleScenePath:    "res://scenes/network/dedicated_server_scene.tscn",
		BattleTicketSecret: "test-ticket-secret",
	})
	router := NewRouter(RouterDeps{
		Allocator:       alloc,
		ProcessRunner:   runner,
		InternalAuth:    auth.NewInternalAuth("primary", "internal-secret", time.Minute),
		AllocateHandler: NewAllocateHandler(alloc, runner),
		ReadyHandler:    NewReadyHandler(alloc),
		ActiveHandler:   NewActiveHandler(alloc),
		ReapHandler:     NewReapHandler(alloc, runner),
	})

	body := []byte(`{"battle_id":"battle_lifecycle","assignment_id":"assign_1","match_id":"match_1","expected_member_count":2}`)
	allocateResp := sendSignedRequest(t, router, "/internal/v1/battles/allocate", body, "primary", "internal-secret")
	if allocateResp.Code != http.StatusOK {
		t.Fatalf("allocate expected 200, got %d body=%s", allocateResp.Code, allocateResp.Body.String())
	}
	var allocatePayload map[string]any
	if err := json.Unmarshal(allocateResp.Body.Bytes(), &allocatePayload); err != nil {
		t.Fatalf("decode allocate response failed: %v", err)
	}
	if got := allocatePayload["allocation_state"]; got != "starting" {
		t.Fatalf("allocate should start in starting state, got %v", got)
	}

	readyResp := sendSignedRequest(t, router, "/internal/v1/battles/battle_lifecycle/ready", []byte(`{}`), "primary", "internal-secret")
	if readyResp.Code != http.StatusOK {
		t.Fatalf("ready expected 200, got %d body=%s", readyResp.Code, readyResp.Body.String())
	}
	var readyPayload map[string]any
	if err := json.Unmarshal(readyResp.Body.Bytes(), &readyPayload); err != nil {
		t.Fatalf("decode ready response failed: %v", err)
	}
	if got := readyPayload["state"]; got != "ready" {
		t.Fatalf("ready endpoint should set ready state, got %v", got)
	}

	activeResp := sendSignedRequest(t, router, "/internal/v1/battles/battle_lifecycle/active", []byte(`{}`), "primary", "internal-secret")
	if activeResp.Code != http.StatusOK {
		t.Fatalf("active expected 200, got %d body=%s", activeResp.Code, activeResp.Body.String())
	}
	var activePayload map[string]any
	if err := json.Unmarshal(activeResp.Body.Bytes(), &activePayload); err != nil {
		t.Fatalf("decode active response failed: %v", err)
	}
	if got := activePayload["state"]; got != "active" {
		t.Fatalf("active endpoint should set active state, got %v", got)
	}

	reapResp := sendSignedRequest(t, router, "/internal/v1/battles/battle_lifecycle/reap", []byte(`{}`), "primary", "internal-secret")
	if reapResp.Code != http.StatusOK {
		t.Fatalf("reap expected 200, got %d body=%s", reapResp.Code, reapResp.Body.String())
	}
	var reapPayload map[string]any
	if err := json.Unmarshal(reapResp.Body.Bytes(), &reapPayload); err != nil {
		t.Fatalf("decode reap response failed: %v", err)
	}
	if got := reapPayload["reaped"]; got != true {
		t.Fatalf("reap response should report reaped=true, got %v", got)
	}
}

func newTestRouter(t *testing.T) http.Handler {
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

func sendSignedRequest(t *testing.T, router http.Handler, path string, body []byte, keyID string, secret string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	if keyID != "" && secret != "" {
		if err := internalhttp.SignRequest(req, keyID, secret, body, time.Now().UTC()); err != nil {
			t.Fatalf("sign request: %v", err)
		}
	}
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)
	return resp
}

func createNoopExecutable(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if runtime.GOOS == "windows" {
		path := filepath.Join(dir, "noop.cmd")
		content := "@echo off\r\nping -n 6 127.0.0.1 >nul\r\nexit /b 0\r\n"
		if err := os.WriteFile(path, []byte(content), 0644); err != nil {
			t.Fatalf("write noop cmd failed: %v", err)
		}
		return path
	}

	path := filepath.Join(dir, "noop.sh")
	content := "#!/usr/bin/env sh\nsleep 5\n"
	if err := os.WriteFile(path, []byte(content), 0755); err != nil {
		t.Fatalf("write noop script failed: %v", err)
	}
	if err := os.Chmod(path, 0755); err != nil {
		t.Fatalf("chmod noop script failed: %v", err)
	}
	return path
}
