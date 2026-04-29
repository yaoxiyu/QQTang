package runtimepool

import (
	"context"
	"testing"
)

func TestFakePoolAllocateReturnsFixedEndpoint(t *testing.T) {
	pool := NewFakePool("qqt-ds-slot-001", 9000)

	result, err := pool.Allocate(context.Background(), AllocationSpec{
		BattleID:     "battle-1",
		AssignmentID: "assign-1",
		MatchID:      "match-1",
	})
	if err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if !result.OK {
		t.Fatalf("expected OK result: %+v", result)
	}
	if result.ServerHost != "qqt-ds-slot-001" || result.ServerPort != 9000 {
		t.Fatalf("unexpected endpoint: %+v", result)
	}
	if result.AllocationState != "ready" || result.PoolState != "bound_ready" {
		t.Fatalf("unexpected state: %+v", result)
	}
}

func TestFakePoolAllocateIsIdempotentByBattleID(t *testing.T) {
	pool := NewFakePool("qqt-ds-slot-001", 9000)

	first, err := pool.Allocate(context.Background(), AllocationSpec{BattleID: "battle-1"})
	if err != nil {
		t.Fatalf("first Allocate returned error: %v", err)
	}
	second, err := pool.Allocate(context.Background(), AllocationSpec{BattleID: "battle-1"})
	if err != nil {
		t.Fatalf("second Allocate returned error: %v", err)
	}
	if first != second {
		t.Fatalf("expected same allocation, first=%+v second=%+v", first, second)
	}
}

func TestFakePoolAllocateIsIdempotentByKey(t *testing.T) {
	pool := NewFakePool("qqt-ds-slot-001", 9000)

	first, err := pool.Allocate(context.Background(), AllocationSpec{
		BattleID:       "battle-1",
		IdempotencyKey: "assign-1:battle-1",
	})
	if err != nil {
		t.Fatalf("first Allocate returned error: %v", err)
	}
	second, err := pool.Allocate(context.Background(), AllocationSpec{
		BattleID:       "battle-2",
		IdempotencyKey: "assign-1:battle-1",
	})
	if err != nil {
		t.Fatalf("second Allocate returned error: %v", err)
	}
	if first != second {
		t.Fatalf("expected same allocation, first=%+v second=%+v", first, second)
	}
}

func TestFakePoolReadyActiveReap(t *testing.T) {
	pool := NewFakePool("qqt-ds-slot-001", 9000)
	if _, err := pool.Allocate(context.Background(), AllocationSpec{BattleID: "battle-1"}); err != nil {
		t.Fatalf("Allocate returned error: %v", err)
	}
	if err := pool.MarkActive(context.Background(), "battle-1"); err != nil {
		t.Fatalf("MarkActive returned error: %v", err)
	}
	active, err := pool.GetBattle(context.Background(), "battle-1")
	if err != nil {
		t.Fatalf("GetBattle returned error: %v", err)
	}
	if active.AllocationState != "active" || active.PoolState != "active" {
		t.Fatalf("unexpected active state: %+v", active)
	}
	if err := pool.Reap(context.Background(), "battle-1"); err != nil {
		t.Fatalf("Reap returned error: %v", err)
	}
	if _, err := pool.GetBattle(context.Background(), "battle-1"); err != ErrBattleNotFound {
		t.Fatalf("expected ErrBattleNotFound, got %v", err)
	}
}
