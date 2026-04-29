package dockerwarm

import (
	"fmt"
	"sync"
	"time"
)

type Lease struct {
	LeaseID        string
	BattleID       string
	AssignmentID   string
	MatchID        string
	SlotID         string
	IdempotencyKey string
	State          string
	ServerHost     string
	ServerPort     int
	CreatedAt      time.Time
	AssignedAt     time.Time
	ReadyAt        time.Time
	ActiveAt       time.Time
	ExpiresAt      time.Time
	UpdatedAt      time.Time
	Version        int64
}

type LeaseRegistry struct {
	mu       sync.Mutex
	byBattle map[string]*Lease
	bySlot   map[string]*Lease
	byIDKey  map[string]*Lease
}

func NewLeaseRegistry() *LeaseRegistry {
	return &LeaseRegistry{
		byBattle: map[string]*Lease{},
		bySlot:   map[string]*Lease{},
		byIDKey:  map[string]*Lease{},
	}
}

func (r *LeaseRegistry) Put(lease Lease) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if lease.BattleID == "" || lease.SlotID == "" || lease.LeaseID == "" {
		return fmt.Errorf("lease_id, battle_id, and slot_id are required")
	}
	copy := lease
	r.byBattle[lease.BattleID] = &copy
	r.bySlot[lease.SlotID] = &copy
	if lease.IdempotencyKey != "" {
		r.byIDKey[lease.IdempotencyKey] = &copy
	}
	return nil
}

func (r *LeaseRegistry) GetByBattle(battleID string) (Lease, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	lease, ok := r.byBattle[battleID]
	if !ok {
		return Lease{}, false
	}
	return *lease, true
}

func (r *LeaseRegistry) GetBySlot(slotID string) (Lease, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	lease, ok := r.bySlot[slotID]
	if !ok {
		return Lease{}, false
	}
	return *lease, true
}

func (r *LeaseRegistry) GetByIdempotencyKey(key string) (Lease, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	lease, ok := r.byIDKey[key]
	if !ok {
		return Lease{}, false
	}
	return *lease, true
}

func (r *LeaseRegistry) DeleteByBattle(battleID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	lease, ok := r.byBattle[battleID]
	if !ok {
		return
	}
	delete(r.byBattle, battleID)
	delete(r.bySlot, lease.SlotID)
	if lease.IdempotencyKey != "" {
		delete(r.byIDKey, lease.IdempotencyKey)
	}
}
