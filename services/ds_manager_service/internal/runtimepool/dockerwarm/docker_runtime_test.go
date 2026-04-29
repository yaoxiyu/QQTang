package dockerwarm

import (
	"context"
	"testing"
	"time"
)

func TestBuildLabels(t *testing.T) {
	createdAt := time.Date(2026, 4, 28, 10, 0, 0, 0, time.UTC)
	labels := BuildLabels("pool-1", "slot-1", "ds-1", createdAt)

	if labels[LabelComponent] != LabelComponentBattleDS {
		t.Fatalf("component label = %q", labels[LabelComponent])
	}
	if labels[LabelManagedBy] != LabelManagedByDSM {
		t.Fatalf("managed_by label = %q", labels[LabelManagedBy])
	}
	if labels[LabelPoolID] != "pool-1" || labels[LabelSlotID] != "slot-1" || labels[LabelDSInstanceID] != "ds-1" {
		t.Fatalf("unexpected identity labels: %+v", labels)
	}
	if labels[LabelCreatedAt] == "" {
		t.Fatalf("missing created_at label")
	}
}

func TestFakeContainerRuntimeLifecycle(t *testing.T) {
	runtime := NewFakeContainerRuntime()
	ctx := context.Background()

	created, err := runtime.CreateWarmContainer(ctx, ContainerSpec{
		PoolID:       "pool-1",
		SlotID:       "slot-1",
		DSInstanceID: "ds-1",
		Name:         "qqt-ds-slot-1",
		Image:        "qqtang/battle-ds:dev",
		NetworkName:  "qqtang_services_dev_default",
		AgentPort:    19090,
		BattlePort:   9000,
	})
	if err != nil {
		t.Fatalf("CreateWarmContainer returned error: %v", err)
	}
	if created.State != "created" {
		t.Fatalf("created state = %q", created.State)
	}
	if created.AgentEndpoint != "http://qqt-ds-slot-1:19090" {
		t.Fatalf("AgentEndpoint = %q", created.AgentEndpoint)
	}

	if err := runtime.StartContainer(ctx, created.ContainerID); err != nil {
		t.Fatalf("StartContainer returned error: %v", err)
	}
	inspected, err := runtime.InspectContainer(ctx, created.ContainerID)
	if err != nil {
		t.Fatalf("InspectContainer returned error: %v", err)
	}
	if inspected.State != "running" {
		t.Fatalf("state = %q", inspected.State)
	}

	listed, err := runtime.ListPoolContainers(ctx, "pool-1")
	if err != nil {
		t.Fatalf("ListPoolContainers returned error: %v", err)
	}
	if len(listed) != 1 {
		t.Fatalf("listed containers = %d", len(listed))
	}

	if err := runtime.StopContainer(ctx, created.ContainerID, time.Second); err != nil {
		t.Fatalf("StopContainer returned error: %v", err)
	}
	if err := runtime.RemoveContainer(ctx, created.ContainerID); err != nil {
		t.Fatalf("RemoveContainer returned error: %v", err)
	}
	listed, err = runtime.ListPoolContainers(ctx, "pool-1")
	if err != nil {
		t.Fatalf("ListPoolContainers returned error: %v", err)
	}
	if len(listed) != 0 {
		t.Fatalf("listed containers after remove = %d", len(listed))
	}
}
