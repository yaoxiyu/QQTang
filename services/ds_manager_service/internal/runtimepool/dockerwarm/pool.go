package dockerwarm

import (
	"context"
	"fmt"
	"time"

	"qqtang/services/ds_manager_service/internal/runtimepool"
)

type PoolConfig struct {
	WarmPoolConfig
	AdvertiseMode      string
	PublicHost         string
	GameServiceBaseURL string
	DSMBaseURL         string
	ReadyTimeoutMS     int
	ReadyTimeoutSec    int
	IdleReapTimeoutSec int
}

type DockerWarmPool struct {
	config   PoolConfig
	manager  *WarmPoolManager
	runtime  ContainerRuntime
	agent    AgentClient
	registry *LeaseRegistry
}

func NewDockerWarmPool(cfg PoolConfig, containerRuntime ContainerRuntime, agent AgentClient, registry *LeaseRegistry) *DockerWarmPool {
	if registry == nil {
		registry = NewLeaseRegistry()
	}
	if cfg.AdvertiseMode == "" {
		cfg.AdvertiseMode = "container_name"
	}
	manager := NewWarmPoolManager(cfg.WarmPoolConfig, containerRuntime, agent)
	return &DockerWarmPool{
		config:   cfg,
		manager:  manager,
		runtime:  containerRuntime,
		agent:    agent,
		registry: registry,
	}
}

func (p *DockerWarmPool) Allocate(ctx context.Context, spec runtimepool.AllocationSpec) (runtimepool.AllocationResult, error) {
	if spec.BattleID == "" {
		return runtimepool.AllocationResult{OK: false, ErrorCode: "MISSING_BATTLE_ID", Message: "battle_id is required"}, nil
	}
	if lease, ok := p.registry.GetByBattle(spec.BattleID); ok {
		return allocationResultFromLease(lease), nil
	}
	if spec.IdempotencyKey != "" {
		if lease, ok := p.registry.GetByIdempotencyKey(spec.IdempotencyKey); ok {
			return allocationResultFromLease(lease), nil
		}
	}

	slot, err := p.findIdleSlot(ctx)
	if err != nil {
		return runtimepool.AllocationResult{}, err
	}
	if slot.ContainerID == "" {
		containers, err := p.runtime.ListPoolContainers(ctx, p.config.PoolID)
		if err != nil {
			return runtimepool.AllocationResult{}, err
		}
		if len(containers) >= p.config.MaxSize {
			return runtimepool.AllocationResult{
				OK:        false,
				ErrorCode: "DS_POOL_EXHAUSTED",
				Message:   "no idle ready ds container and max pool size reached",
			}, nil
		}
		slot, err = p.manager.createAndStartSlot(ctx, len(containers))
		if err != nil {
			return runtimepool.AllocationResult{}, err
		}
	}

	serverHost, serverPort, err := p.resolveAdvertiseEndpoint(slot)
	if err != nil {
		return runtimepool.AllocationResult{OK: false, ErrorCode: "DS_ENDPOINT_INVALID", Message: err.Error()}, nil
	}

	now := time.Now().UTC()
	lease := Lease{
		LeaseID:        fmt.Sprintf("lease_%s_%d", spec.BattleID, now.UnixNano()),
		BattleID:       spec.BattleID,
		AssignmentID:   spec.AssignmentID,
		MatchID:        spec.MatchID,
		SlotID:         slot.Labels[LabelSlotID],
		IdempotencyKey: spec.IdempotencyKey,
		State:          "ASSIGNING",
		ServerHost:     serverHost,
		ServerPort:     serverPort,
		CreatedAt:      now,
		AssignedAt:     now,
		UpdatedAt:      now,
		Version:        1,
	}
	if err := p.registry.Put(lease); err != nil {
		return runtimepool.AllocationResult{}, err
	}

	agentState, err := p.agent.Assign(ctx, slot.AgentEndpoint, AgentAssignRequest{
		LeaseID:             lease.LeaseID,
		BattleID:            spec.BattleID,
		AssignmentID:        spec.AssignmentID,
		MatchID:             spec.MatchID,
		ExpectedMemberCount: spec.ExpectedMemberCount,
		AdvertiseHost:       serverHost,
		AdvertisePort:       serverPort,
		GameServiceBaseURL:  p.config.GameServiceBaseURL,
		DSMBaseURL:          p.config.DSMBaseURL,
		ReadyTimeoutMS:      p.config.ReadyTimeoutMS,
	})
	if err != nil {
		p.registry.DeleteByBattle(spec.BattleID)
		return runtimepool.AllocationResult{OK: false, ErrorCode: "DS_AGENT_ASSIGN_FAILED", Message: err.Error()}, nil
	}
	if agentState.State == "idle" {
		p.registry.DeleteByBattle(spec.BattleID)
		return runtimepool.AllocationResult{OK: false, ErrorCode: "DS_AGENT_ASSIGN_REJECTED", Message: "agent remained idle after assign"}, nil
	}

	if !spec.WaitReady {
		return allocationResultFromLease(lease), nil
	}

	readyLease, ok := p.waitReady(ctx, spec.BattleID)
	if !ok {
		lease.State = "FAILED"
		lease.UpdatedAt = time.Now().UTC()
		lease.Version++
		_ = p.registry.Put(lease)
		_, _ = p.agent.Reset(ctx, slot.AgentEndpoint)
		return runtimepool.AllocationResult{
			OK:        false,
			ErrorCode: "DS_READY_TIMEOUT",
			Message:   "ds did not report ready before timeout",
		}, nil
	}
	return allocationResultFromLease(readyLease), nil
}

func (p *DockerWarmPool) MarkReady(_ context.Context, battleID string) error {
	lease, ok := p.registry.GetByBattle(battleID)
	if !ok {
		return runtimepool.ErrBattleNotFound
	}
	lease.State = "READY"
	lease.ReadyAt = time.Now().UTC()
	lease.UpdatedAt = lease.ReadyAt
	lease.Version++
	return p.registry.Put(lease)
}

func (p *DockerWarmPool) MarkActive(_ context.Context, battleID string) error {
	lease, ok := p.registry.GetByBattle(battleID)
	if !ok {
		return runtimepool.ErrBattleNotFound
	}
	lease.State = "ACTIVE"
	lease.ActiveAt = time.Now().UTC()
	lease.UpdatedAt = lease.ActiveAt
	lease.Version++
	return p.registry.Put(lease)
}

func (p *DockerWarmPool) Reap(ctx context.Context, battleID string) error {
	lease, ok := p.registry.GetByBattle(battleID)
	if !ok {
		return runtimepool.ErrBattleNotFound
	}
	containers, err := p.runtime.ListPoolContainers(ctx, p.config.PoolID)
	if err != nil {
		return err
	}
	for _, container := range containers {
		if container.Labels[LabelSlotID] == lease.SlotID {
			_, _ = p.agent.Reset(ctx, container.AgentEndpoint)
			break
		}
	}
	p.registry.DeleteByBattle(battleID)
	return nil
}

func (p *DockerWarmPool) GetBattle(_ context.Context, battleID string) (runtimepool.AllocationResult, error) {
	lease, ok := p.registry.GetByBattle(battleID)
	if !ok {
		return runtimepool.AllocationResult{}, runtimepool.ErrBattleNotFound
	}
	return allocationResultFromLease(lease), nil
}

func (p *DockerWarmPool) Reconcile(ctx context.Context) error {
	if err := p.manager.Reconcile(ctx); err != nil {
		return err
	}
	return p.reapStaleLeases(ctx)
}

func (p *DockerWarmPool) reapStaleLeases(ctx context.Context) error {
	leases := p.registry.All()
	if len(leases) == 0 {
		return nil
	}

	containers, err := p.runtime.ListPoolContainers(ctx, p.config.PoolID)
	if err != nil {
		return err
	}
	containerBySlot := map[string]ContainerInfo{}
	for _, c := range containers {
		containerBySlot[c.Labels[LabelSlotID]] = c
	}

	now := time.Now().UTC()
	assignTimeout := time.Duration(p.config.ReadyTimeoutSec) * time.Second * 2
	if assignTimeout < 30*time.Second {
		assignTimeout = 30 * time.Second
	}
	idleTimeout := time.Duration(p.config.IdleReapTimeoutSec) * time.Second

	for _, lease := range leases {
		var shouldReap bool

		switch lease.State {
		case "FAILED":
			shouldReap = true
		case "ASSIGNING":
			if now.After(lease.CreatedAt.Add(assignTimeout)) {
				shouldReap = true
			}
		case "READY":
			if !lease.ReadyAt.IsZero() && now.After(lease.ReadyAt.Add(idleTimeout)) {
				shouldReap = true
			}
		case "ACTIVE":
			container, exists := containerBySlot[lease.SlotID]
			if !exists {
				shouldReap = true
			} else {
				agentState, err := p.agent.State(ctx, container.AgentEndpoint)
				if err == nil && agentState.State == "idle" {
					shouldReap = true
				}
			}
		}

		if shouldReap {
			if container, ok := containerBySlot[lease.SlotID]; ok {
				_, _ = p.agent.Reset(ctx, container.AgentEndpoint)
			}
			p.registry.DeleteByBattle(lease.BattleID)
		}
	}

	return nil
}

func (p *DockerWarmPool) waitReady(ctx context.Context, battleID string) (Lease, bool) {
	timeout := time.Duration(p.config.ReadyTimeoutMS) * time.Millisecond
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	deadline := time.NewTimer(timeout)
	defer deadline.Stop()
	ticker := time.NewTicker(25 * time.Millisecond)
	defer ticker.Stop()
	for {
		lease, ok := p.registry.GetByBattle(battleID)
		if ok && (lease.State == "READY" || lease.State == "ACTIVE") {
			return lease, true
		}
		select {
		case <-ctx.Done():
			return Lease{}, false
		case <-deadline.C:
			return Lease{}, false
		case <-ticker.C:
		}
	}
}

func (p *DockerWarmPool) findIdleSlot(ctx context.Context) (ContainerInfo, error) {
	containers, err := p.runtime.ListPoolContainers(ctx, p.config.PoolID)
	if err != nil {
		return ContainerInfo{}, err
	}
	for _, container := range containers {
		if container.State != "running" {
			continue
		}
		if _, ok := p.registry.GetBySlot(container.Labels[LabelSlotID]); ok {
			continue
		}
		if err := p.agent.Health(ctx, container.AgentEndpoint); err != nil {
			continue
		}
		agentState, err := p.agent.State(ctx, container.AgentEndpoint)
		if err != nil {
			continue
		}
		if agentState.State == "idle" {
			return container, nil
		}
	}
	return ContainerInfo{}, nil
}

func (p *DockerWarmPool) resolveAdvertiseEndpoint(slot ContainerInfo) (string, int, error) {
	switch p.config.AdvertiseMode {
	case "container_name":
		if slot.Name == "" {
			return "", 0, fmt.Errorf("container name is empty")
		}
		return slot.Name, p.config.DSBattlePort, nil
	case "public_host_port":
		if p.config.PublicHost == "" {
			return "", 0, fmt.Errorf("public host is required for public_host_port mode")
		}
		port := slot.PublishedPort
		if port <= 0 {
			port = slot.BattlePort
		}
		if port <= 0 {
			return "", 0, fmt.Errorf("published port is empty")
		}
		return p.config.PublicHost, port, nil
	default:
		return "", 0, fmt.Errorf("unsupported advertise mode %q", p.config.AdvertiseMode)
	}
}

func allocationResultFromLease(lease Lease) runtimepool.AllocationResult {
	allocationState := "assigning"
	poolState := "assigning"
	serverHost := ""
	serverPort := 0
	switch lease.State {
	case "READY":
		allocationState = "ready"
		poolState = "bound_ready"
		serverHost = lease.ServerHost
		serverPort = lease.ServerPort
	case "ACTIVE":
		allocationState = "active"
		poolState = "active"
		serverHost = lease.ServerHost
		serverPort = lease.ServerPort
	case "FAILED":
		allocationState = "allocation_failed"
		poolState = "failed"
	}
	return runtimepool.AllocationResult{
		OK:              true,
		DSInstanceID:    "ds_" + lease.SlotID,
		LeaseID:         lease.LeaseID,
		AllocationState: allocationState,
		ServerHost:      serverHost,
		ServerPort:      serverPort,
		PoolState:       poolState,
	}
}
