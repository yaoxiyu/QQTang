package runtimepool

import "context"

type RuntimePool interface {
	Allocate(ctx context.Context, spec AllocationSpec) (AllocationResult, error)
	MarkReady(ctx context.Context, battleID string) error
	MarkActive(ctx context.Context, battleID string) error
	Reap(ctx context.Context, battleID string) error
	GetBattle(ctx context.Context, battleID string) (AllocationResult, error)
	Reconcile(ctx context.Context) error
}
