package dockerwarm

import (
	"context"
	"fmt"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/runtimepool"
)

func TestDockerWarmPoolAllocateIdleSlot(t *testing.T) {
	pool, _, _ := newTestDockerWarmPool(t)
	ctx := context.Background()
	go waitForLeaseAndMarkReady(t, pool, "battle-1")

	result, err := pool.Allocate(ctx, runtimepool.AllocationSpec{
		BattleID:            "battle-1",
		AssignmentID:        "assign-1",
		MatchID:             "match-1",
		ExpectedMemberCount: 2,
		IdempotencyKey:      "assign-1:battle-1",
		WaitReady:           true,
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if !result.OK {
		t.Fatalf("expected OK allocation: %+v", result)
	}
	if result.AllocationState != "ready" || result.PoolState != "bound_ready" {
		t.Fatalf("unexpected state: %+v", result)
	}
	if result.ServerHost == "" || result.ServerHost == "127.0.0.1" || result.ServerPort != 9000 {
		t.Fatalf("unexpected endpoint: %+v", result)
	}
}

func TestDockerWarmPoolAllocateIdempotent(t *testing.T) {
	pool, _, _ := newTestDockerWarmPool(t)
	ctx := context.Background()

	first, err := pool.Allocate(ctx, runtimepool.AllocationSpec{
		BattleID:       "battle-1",
		AssignmentID:   "assign-1",
		MatchID:        "match-1",
		IdempotencyKey: "assign-1:battle-1",
	})
	if err != nil {
		t.Fatalf("first Allocate returned error: %v", err)
	}
	second, err := pool.Allocate(ctx, runtimepool.AllocationSpec{
		BattleID:       "battle-1",
		AssignmentID:   "assign-1",
		MatchID:        "match-1",
		IdempotencyKey: "assign-1:battle-1",
	})
	if err != nil {
		t.Fatalf("second Allocate returned error: %v", err)
	}
	if first.LeaseID != second.LeaseID || first.ServerHost != second.ServerHost {
		t.Fatalf("expected same lease, first=%+v second=%+v", first, second)
	}
}

func TestDockerWarmPoolAllocateWithoutWaitReadyDoesNotExposeEndpoint(t *testing.T) {
	pool, _, _ := newTestDockerWarmPool(t)

	result, err := pool.Allocate(context.Background(), runtimepool.AllocationSpec{
		BattleID:     "battle-1",
		AssignmentID: "assign-1",
		MatchID:      "match-1",
		WaitReady:    false,
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if !result.OK || result.AllocationState != "assigning" {
		t.Fatalf("expected assigning result, got %+v", result)
	}
	if result.ServerHost != "" || result.ServerPort != 0 {
		t.Fatalf("assigning allocation must not expose endpoint: %+v", result)
	}

	if err := pool.MarkReady(context.Background(), "battle-1"); err != nil {
		t.Fatalf("MarkReady returned error: %v", err)
	}
	ready, err := pool.GetBattle(context.Background(), "battle-1")
	if err != nil {
		t.Fatalf("GetBattle returned error: %v", err)
	}
	if ready.AllocationState != "ready" || ready.ServerHost == "" || ready.ServerPort == 0 {
		t.Fatalf("expected ready endpoint after MarkReady, got %+v", ready)
	}
}

func TestDockerWarmPoolWaitReadyTimeoutFailsAllocation(t *testing.T) {
	pool, _, _ := newTestDockerWarmPool(t)
	pool.config.ReadyTimeoutMS = 1

	result, err := pool.Allocate(context.Background(), runtimepool.AllocationSpec{
		BattleID:     "battle-1",
		AssignmentID: "assign-1",
		MatchID:      "match-1",
		WaitReady:    true,
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if result.OK || result.ErrorCode != "DS_READY_TIMEOUT" {
		t.Fatalf("expected DS_READY_TIMEOUT, got %+v", result)
	}
	status, err := pool.GetBattle(context.Background(), "battle-1")
	if err != nil {
		t.Fatalf("GetBattle returned error: %v", err)
	}
	if status.AllocationState != "allocation_failed" {
		t.Fatalf("expected failed status, got %+v", status)
	}
}

func TestDockerWarmPoolPoolExhausted(t *testing.T) {
	cfg := testPoolConfig()
	cfg.MaxSize = 0
	runtime := NewFakeContainerRuntime()
	agent := NewFakeAgentClient()
	pool := NewDockerWarmPool(cfg, runtime, agent, NewLeaseRegistry())

	result, err := pool.Allocate(context.Background(), runtimepool.AllocationSpec{
		BattleID:     "battle-1",
		AssignmentID: "assign-1",
		MatchID:      "match-1",
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if result.OK || result.ErrorCode != "DS_POOL_EXHAUSTED" {
		t.Fatalf("expected DS_POOL_EXHAUSTED, got %+v", result)
	}
}

func TestDockerWarmPoolAssignFailureDoesNotKeepLease(t *testing.T) {
	pool, _, agent := newTestDockerWarmPool(t)
	agent.AssignFailures["http://qqt-ds-slot-001:19090"] = fmt.Errorf("assign failed")

	result, err := pool.Allocate(context.Background(), runtimepool.AllocationSpec{
		BattleID:     "battle-1",
		AssignmentID: "assign-1",
		MatchID:      "match-1",
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if result.OK || result.ErrorCode != "DS_AGENT_ASSIGN_FAILED" {
		t.Fatalf("expected assign failure, got %+v", result)
	}
	if _, err := pool.GetBattle(context.Background(), "battle-1"); err != runtimepool.ErrBattleNotFound {
		t.Fatalf("expected lease cleanup, got err=%v", err)
	}
}

func newTestDockerWarmPool(t *testing.T) (*DockerWarmPool, *FakeContainerRuntime, *FakeAgentClient) {
	t.Helper()
	runtime := NewFakeContainerRuntime()
	agent := NewFakeAgentClient()
	pool := NewDockerWarmPool(testPoolConfig(), runtime, agent, NewLeaseRegistry())
	ctx := context.Background()
	info, err := runtime.CreateWarmContainer(ctx, ContainerSpec{
		PoolID:       "pool-1",
		SlotID:       "slot-001",
		DSInstanceID: "ds-slot-001",
		Name:         "qqt-ds-slot-001",
		Image:        "qqtang/battle-ds:dev",
		NetworkName:  "qqtang_services_dev_default",
		AgentPort:    19090,
		BattlePort:   9000,
	})
	if err != nil {
		t.Fatalf("CreateWarmContainer returned error: %v", err)
	}
	if err := runtime.StartContainer(ctx, info.ContainerID); err != nil {
		t.Fatalf("StartContainer returned error: %v", err)
	}
	return pool, runtime, agent
}

func testPoolConfig() PoolConfig {
	return PoolConfig{
		WarmPoolConfig:     testWarmPoolConfig(),
		AdvertiseMode:      "container_name",
		ReadyTimeoutMS:     5000,
		GameServiceBaseURL: "http://game_service:18081",
		DSMBaseURL:         "http://ds_manager_service:18090",
	}
}

func waitForLeaseAndMarkReady(t *testing.T, pool *DockerWarmPool, battleID string) {
	t.Helper()
	deadline := time.After(500 * time.Millisecond)
	ticker := time.NewTicker(time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-deadline:
			t.Errorf("timed out waiting for lease")
			return
		case <-ticker.C:
			if _, err := pool.GetBattle(context.Background(), battleID); err == nil {
				if err := pool.MarkReady(context.Background(), battleID); err != nil {
					t.Errorf("MarkReady returned error: %v", err)
				}
				return
			}
		}
	}
}
