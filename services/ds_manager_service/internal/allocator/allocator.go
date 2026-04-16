package allocator

import (
	"fmt"
	"sync"
	"time"
)

type AllocationState string

const (
	StateStarting AllocationState = "starting"
	StateReady    AllocationState = "ready"
	StateActive   AllocationState = "active"
	StateFailed   AllocationState = "failed"
	StateFinished AllocationState = "finished"
)

type DSInstance struct {
	InstanceID   string
	BattleID     string
	AssignmentID string
	MatchID      string
	Host         string
	Port         int
	State        AllocationState
	PID          int
	CreatedAt    time.Time
	ReadyAt      time.Time
	ActiveAt     time.Time
	UpdatedAt    time.Time
}

type AllocateRequest struct {
	BattleID            string
	AssignmentID        string
	MatchID             string
	HostHint            string
	ExpectedMemberCount int
}

type AllocateResult struct {
	InstanceID string
	Host       string
	Port       int
	State      AllocationState
}

type Allocator struct {
	mu        sync.Mutex
	instances map[string]*DSInstance
	portPool  *PortPool
	dsHost    string
}

func New(portStart, portEnd int, dsHost string) *Allocator {
	return &Allocator{
		instances: make(map[string]*DSInstance),
		portPool:  NewPortPool(portStart, portEnd),
		dsHost:    dsHost,
	}
}

func (a *Allocator) Allocate(req AllocateRequest) (*AllocateResult, error) {
	a.mu.Lock()
	defer a.mu.Unlock()

	if _, exists := a.instances[req.BattleID]; exists {
		return nil, fmt.Errorf("battle %s already allocated", req.BattleID)
	}

	port, err := a.portPool.Acquire()
	if err != nil {
		return nil, fmt.Errorf("no available ports: %w", err)
	}

	host := a.dsHost
	if req.HostHint != "" {
		host = req.HostHint
	}

	instanceID := fmt.Sprintf("ds_%s", req.BattleID)
	inst := &DSInstance{
		InstanceID:   instanceID,
		BattleID:     req.BattleID,
		AssignmentID: req.AssignmentID,
		MatchID:      req.MatchID,
		Host:         host,
		Port:         port,
		State:        StateStarting,
		CreatedAt:    time.Now(),
	}
	inst.UpdatedAt = inst.CreatedAt
	a.instances[req.BattleID] = inst

	return &AllocateResult{
		InstanceID: instanceID,
		Host:       host,
		Port:       port,
		State:      StateStarting,
	}, nil
}

func (a *Allocator) SetPID(battleID string, pid int) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if inst, ok := a.instances[battleID]; ok {
		inst.PID = pid
	}
}

func (a *Allocator) MarkReady(battleID string) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	inst, ok := a.instances[battleID]
	if !ok {
		return fmt.Errorf("battle %s not found", battleID)
	}
	if inst.State != StateStarting {
		return fmt.Errorf("battle %s in state %s, expected starting", battleID, inst.State)
	}
	inst.State = StateReady
	now := time.Now()
	inst.ReadyAt = now
	inst.UpdatedAt = now
	return nil
}

func (a *Allocator) MarkActive(battleID string) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	inst, ok := a.instances[battleID]
	if !ok {
		return fmt.Errorf("battle %s not found", battleID)
	}
	inst.State = StateActive
	now := time.Now()
	inst.ActiveAt = now
	inst.UpdatedAt = now
	return nil
}

func (a *Allocator) MarkFailed(battleID string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if inst, ok := a.instances[battleID]; ok {
		inst.State = StateFailed
		inst.UpdatedAt = time.Now()
	}
}

func (a *Allocator) MarkFinished(battleID string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if inst, ok := a.instances[battleID]; ok {
		inst.State = StateFinished
		inst.UpdatedAt = time.Now()
	}
}

func (a *Allocator) Release(battleID string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	inst, ok := a.instances[battleID]
	if !ok {
		return
	}
	a.portPool.Release(inst.Port)
	delete(a.instances, battleID)
}

func (a *Allocator) Get(battleID string) (*DSInstance, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	inst, ok := a.instances[battleID]
	if !ok {
		return nil, false
	}
	copy := *inst
	return &copy, true
}

func (a *Allocator) GetPort(battleID string) (int, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	inst, ok := a.instances[battleID]
	if !ok {
		return 0, false
	}
	return inst.Port, true
}

func (a *Allocator) ListStale(readyTimeout, idleReapTimeout time.Duration) []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	now := time.Now()
	var stale []string
	for battleID, inst := range a.instances {
		switch inst.State {
		case StateStarting:
			if now.Sub(inst.CreatedAt) > readyTimeout {
				stale = append(stale, battleID)
			}
		case StateFinished:
			stale = append(stale, battleID)
		case StateReady:
			if now.Sub(inst.ReadyAt) > idleReapTimeout {
				stale = append(stale, battleID)
			}
		case StateActive:
			continue
		case StateFailed:
			stale = append(stale, battleID)
		}
	}
	return stale
}
