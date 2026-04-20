package httpapi

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/process"
)

func TestDSControlPlaneLifecycleAllocateReadyActiveReap(t *testing.T) {
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
	allocateResp := sendSignedDSMRequest(t, router, "/internal/v1/battles/allocate", body, "primary", "internal-secret")
	if allocateResp.Code != http.StatusOK {
		t.Fatalf("allocate expected 200, got %d body=%s", allocateResp.Code, allocateResp.Body.String())
	}
	var allocatePayload map[string]any
	if err := json.Unmarshal(allocateResp.Body.Bytes(), &allocatePayload); err != nil {
		t.Fatalf("decode allocate response failed: %v", err)
	}
	if got := allocatePayload["allocation_state"]; got != "starting" {
		t.Fatalf("allocate should return starting state, got %v", got)
	}

	readyResp := sendSignedDSMRequest(t, router, "/internal/v1/battles/battle_lifecycle/ready", []byte(`{}`), "primary", "internal-secret")
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

	activeResp := sendSignedDSMRequest(t, router, "/internal/v1/battles/battle_lifecycle/active", []byte(`{}`), "primary", "internal-secret")
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

	reapResp := sendSignedDSMRequest(t, router, "/internal/v1/battles/battle_lifecycle/reap", []byte(`{}`), "primary", "internal-secret")
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

func TestDSControlPlaneMarksFailedWhenProcessExitFails(t *testing.T) {
	executable := createFailingExecutable(t)

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

	body := []byte(`{"battle_id":"battle_fail_exit","assignment_id":"assign_1","match_id":"match_1","expected_member_count":2}`)
	allocateResp := sendSignedDSMRequest(t, router, "/internal/v1/battles/allocate", body, "primary", "internal-secret")
	if allocateResp.Code != http.StatusOK {
		t.Fatalf("allocate expected 200, got %d body=%s", allocateResp.Code, allocateResp.Body.String())
	}

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		inst, ok := alloc.Get("battle_fail_exit")
		if ok && inst.State == allocator.StateFailed {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	inst, ok := alloc.Get("battle_fail_exit")
	if !ok {
		t.Fatalf("expected allocator instance for battle_fail_exit")
	}
	t.Fatalf("expected process exit failure to write back failed state, got %s", inst.State)
}

func createNoopExecutable(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if runtime.GOOS == "windows" {
		path := filepath.Join(dir, "noop.cmd")
		content := "@echo off\r\nping -n 6 127.0.0.1 >nul\r\nexit /b 0\r\n"
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write noop cmd failed: %v", err)
		}
		return path
	}

	path := filepath.Join(dir, "noop.sh")
	content := "#!/usr/bin/env sh\nsleep 5\n"
	if err := os.WriteFile(path, []byte(content), 0o755); err != nil {
		t.Fatalf("write noop script failed: %v", err)
	}
	if err := os.Chmod(path, 0o755); err != nil {
		t.Fatalf("chmod noop script failed: %v", err)
	}
	return path
}

func createFailingExecutable(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if runtime.GOOS == "windows" {
		path := filepath.Join(dir, "fail.cmd")
		content := "@echo off\r\nexit /b 1\r\n"
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write fail cmd failed: %v", err)
		}
		return path
	}

	path := filepath.Join(dir, "fail.sh")
	content := "#!/usr/bin/env sh\nexit 1\n"
	if err := os.WriteFile(path, []byte(content), 0o755); err != nil {
		t.Fatalf("write fail script failed: %v", err)
	}
	if err := os.Chmod(path, 0o755); err != nil {
		t.Fatalf("chmod fail script failed: %v", err)
	}
	return path
}
