package runtimepool

import (
	"context"
	"errors"
	"fmt"
	"sync"
)

var ErrBattleNotFound = errors.New("battle allocation not found")

type FakePool struct {
	mu        sync.Mutex
	host      string
	nextPort  int
	results   map[string]AllocationResult
	idemIndex map[string]string
}

func NewFakePool(host string, firstPort int) *FakePool {
	if host == "" {
		host = "fake-ds"
	}
	if firstPort <= 0 {
		firstPort = 9000
	}
	return &FakePool{
		host:      host,
		nextPort:  firstPort,
		results:   map[string]AllocationResult{},
		idemIndex: map[string]string{},
	}
}

func (p *FakePool) Allocate(_ context.Context, spec AllocationSpec) (AllocationResult, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if spec.BattleID == "" {
		return AllocationResult{OK: false, ErrorCode: "MISSING_BATTLE_ID", Message: "battle_id is required"}, nil
	}
	if existing, ok := p.results[spec.BattleID]; ok {
		return existing, nil
	}
	if spec.IdempotencyKey != "" {
		if battleID, ok := p.idemIndex[spec.IdempotencyKey]; ok {
			return p.results[battleID], nil
		}
	}

	port := p.nextPort
	p.nextPort++
	result := AllocationResult{
		OK:              true,
		DSInstanceID:    fmt.Sprintf("fake_ds_%s", spec.BattleID),
		LeaseID:         fmt.Sprintf("fake_lease_%s", spec.BattleID),
		AllocationState: "ready",
		ServerHost:      p.host,
		ServerPort:      port,
		ControlEndpoint: fmt.Sprintf("http://%s:19090", p.host),
		PoolState:       "bound_ready",
	}
	p.results[spec.BattleID] = result
	if spec.IdempotencyKey != "" {
		p.idemIndex[spec.IdempotencyKey] = spec.BattleID
	}
	return result, nil
}

func (p *FakePool) MarkReady(_ context.Context, battleID string) error {
	return p.updateState(battleID, "ready", "bound_ready")
}

func (p *FakePool) MarkActive(_ context.Context, battleID string) error {
	return p.updateState(battleID, "active", "active")
}

func (p *FakePool) Reap(_ context.Context, battleID string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if _, ok := p.results[battleID]; !ok {
		return ErrBattleNotFound
	}
	delete(p.results, battleID)
	for key, indexedBattleID := range p.idemIndex {
		if indexedBattleID == battleID {
			delete(p.idemIndex, key)
		}
	}
	return nil
}

func (p *FakePool) GetBattle(_ context.Context, battleID string) (AllocationResult, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	result, ok := p.results[battleID]
	if !ok {
		return AllocationResult{}, ErrBattleNotFound
	}
	return result, nil
}

func (p *FakePool) Reconcile(_ context.Context) error {
	return nil
}

func (p *FakePool) updateState(battleID string, allocationState string, poolState string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	result, ok := p.results[battleID]
	if !ok {
		return ErrBattleNotFound
	}
	result.AllocationState = allocationState
	result.PoolState = poolState
	p.results[battleID] = result
	return nil
}
