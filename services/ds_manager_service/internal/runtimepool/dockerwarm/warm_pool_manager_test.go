package dockerwarm

import (
	"context"
	"fmt"
	"testing"
)

func TestWarmPoolManagerPrefillsMinReady(t *testing.T) {
	runtime := NewFakeContainerRuntime()
	agent := NewFakeAgentClient()
	manager := NewWarmPoolManager(testWarmPoolConfig(), runtime, agent)

	if err := manager.Reconcile(context.Background()); err != nil {
		t.Fatalf("Reconcile returned error: %v", err)
	}
	containers, err := runtime.ListPoolContainers(context.Background(), "pool-1")
	if err != nil {
		t.Fatalf("ListPoolContainers returned error: %v", err)
	}
	if len(containers) != 2 {
		t.Fatalf("containers = %d, want 2", len(containers))
	}
	for _, container := range containers {
		if container.State != "running" {
			t.Fatalf("container state = %q", container.State)
		}
		if container.Labels[LabelComponent] != LabelComponentBattleDS {
			t.Fatalf("missing battle ds label: %+v", container.Labels)
		}
	}
}

func TestWarmPoolManagerDoesNotExceedMaxSize(t *testing.T) {
	runtime := NewFakeContainerRuntime()
	agent := NewFakeAgentClient()
	cfg := testWarmPoolConfig()
	cfg.MinReady = 4
	cfg.MaxSize = 3
	cfg.PrefillBatch = 10
	manager := NewWarmPoolManager(cfg, runtime, agent)

	if err := manager.Reconcile(context.Background()); err != nil {
		t.Fatalf("Reconcile returned error: %v", err)
	}
	containers, err := runtime.ListPoolContainers(context.Background(), "pool-1")
	if err != nil {
		t.Fatalf("ListPoolContainers returned error: %v", err)
	}
	if len(containers) != 3 {
		t.Fatalf("containers = %d, want 3", len(containers))
	}
}

func TestWarmPoolManagerReplacesFailedContainer(t *testing.T) {
	runtime := NewFakeContainerRuntime()
	agent := NewFakeAgentClient()
	manager := NewWarmPoolManager(testWarmPoolConfig(), runtime, agent)
	ctx := context.Background()

	created, err := runtime.CreateWarmContainer(ctx, ContainerSpec{
		PoolID:       "pool-1",
		SlotID:       "slot-failed",
		DSInstanceID: "ds-slot-failed",
		Name:         "qqt-ds-slot-failed",
		Image:        "qqtang/battle-ds:dev",
		AgentPort:    19090,
		BattlePort:   9000,
	})
	if err != nil {
		t.Fatalf("CreateWarmContainer returned error: %v", err)
	}
	if err := runtime.StartContainer(ctx, created.ContainerID); err != nil {
		t.Fatalf("StartContainer returned error: %v", err)
	}
	agent.Failures[created.AgentEndpoint] = fmt.Errorf("agent unreachable")

	if err := manager.Reconcile(ctx); err != nil {
		t.Fatalf("Reconcile returned error: %v", err)
	}
	containers, err := runtime.ListPoolContainers(ctx, "pool-1")
	if err != nil {
		t.Fatalf("ListPoolContainers returned error: %v", err)
	}
	if len(containers) != 2 {
		t.Fatalf("containers = %d, want replacement pool of 2", len(containers))
	}
	for _, container := range containers {
		if container.ContainerID == created.ContainerID {
			t.Fatalf("failed container was not removed")
		}
	}
}

func TestLeaseRegistryIndexesLease(t *testing.T) {
	registry := NewLeaseRegistry()
	lease := Lease{
		LeaseID:        "lease-1",
		BattleID:       "battle-1",
		SlotID:         "slot-1",
		IdempotencyKey: "assign-1:battle-1",
		State:          "READY",
	}
	if err := registry.Put(lease); err != nil {
		t.Fatalf("Put returned error: %v", err)
	}
	if got, ok := registry.GetByBattle("battle-1"); !ok || got.LeaseID != "lease-1" {
		t.Fatalf("GetByBattle = %+v, %v", got, ok)
	}
	if got, ok := registry.GetBySlot("slot-1"); !ok || got.BattleID != "battle-1" {
		t.Fatalf("GetBySlot = %+v, %v", got, ok)
	}
	if got, ok := registry.GetByIdempotencyKey("assign-1:battle-1"); !ok || got.SlotID != "slot-1" {
		t.Fatalf("GetByIdempotencyKey = %+v, %v", got, ok)
	}
	registry.DeleteByBattle("battle-1")
	if _, ok := registry.GetByBattle("battle-1"); ok {
		t.Fatalf("lease still indexed after delete")
	}
}

func testWarmPoolConfig() WarmPoolConfig {
	return WarmPoolConfig{
		PoolID:            "pool-1",
		MinReady:          2,
		MaxSize:           4,
		PrefillBatch:      2,
		DSImage:           "qqtang/battle-ds:dev",
		DSNetwork:         "qqtang_services_dev_default",
		DSContainerPrefix: "qqt-ds",
		DSAgentPort:       19090,
		DSBattlePort:      9000,
	}
}
