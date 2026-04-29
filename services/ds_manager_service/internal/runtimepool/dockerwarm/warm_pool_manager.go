package dockerwarm

import (
	"context"
	"fmt"
	"time"
)

const (
	PoolSlotStateIdleReady = "IDLE_READY"
	PoolSlotStateActive    = "ACTIVE"
	PoolSlotStateFailed    = "FAILED"
)

type WarmPoolConfig struct {
	PoolID            string
	MinReady          int
	MaxSize           int
	PrefillBatch      int
	DSImage           string
	DSNetwork         string
	DSContainerPrefix string
	DSAgentPort       int
	DSBattlePort      int
	DSHostPortStart   int
	DSHostPortEnd     int
	ContainerEnv      map[string]string
}

type WarmPoolManager struct {
	config  WarmPoolConfig
	runtime ContainerRuntime
	agent   AgentClient
}

func NewWarmPoolManager(cfg WarmPoolConfig, runtime ContainerRuntime, agent AgentClient) *WarmPoolManager {
	if cfg.PoolID == "" {
		cfg.PoolID = "default"
	}
	if cfg.MinReady <= 0 {
		cfg.MinReady = 1
	}
	if cfg.MaxSize <= 0 {
		cfg.MaxSize = cfg.MinReady
	}
	if cfg.PrefillBatch <= 0 {
		cfg.PrefillBatch = 1
	}
	if cfg.DSContainerPrefix == "" {
		cfg.DSContainerPrefix = "qqt-ds"
	}
	if cfg.DSHostPortEnd > 0 && cfg.DSHostPortStart > 0 && cfg.DSHostPortEnd <= cfg.DSHostPortStart {
		cfg.DSHostPortEnd = cfg.DSHostPortStart + 1
	}
	return &WarmPoolManager{
		config:  cfg,
		runtime: runtime,
		agent:   agent,
	}
}

func (m *WarmPoolManager) Reconcile(ctx context.Context) error {
	containers, err := m.runtime.ListPoolContainers(ctx, m.config.PoolID)
	if err != nil {
		return err
	}

	idleReady := 0
	activeOrAssigned := 0
	for _, container := range containers {
		if container.State == "failed" || container.State == "exited" || container.State == "stopped" {
			if err := m.runtime.RemoveContainer(ctx, container.ContainerID); err != nil {
				return err
			}
			continue
		}
		if container.State != "running" {
			continue
		}
		if err := m.agent.Health(ctx, container.AgentEndpoint); err != nil {
			if err := m.runtime.StopContainer(ctx, container.ContainerID, time.Second); err != nil {
				return err
			}
			if err := m.runtime.RemoveContainer(ctx, container.ContainerID); err != nil {
				return err
			}
			continue
		}
		agentState, err := m.agent.State(ctx, container.AgentEndpoint)
		if err != nil {
			return err
		}
		switch agentState.State {
		case "idle":
			idleReady++
		default:
			activeOrAssigned++
		}
	}

	containers, err = m.runtime.ListPoolContainers(ctx, m.config.PoolID)
	if err != nil {
		return err
	}
	total := len(containers)
	needed := m.config.MinReady - idleReady
	if needed <= 0 {
		return nil
	}
	if needed > m.config.PrefillBatch {
		needed = m.config.PrefillBatch
	}
	if capacity := m.config.MaxSize - total; needed > capacity {
		needed = capacity
	}
	for i := 0; i < needed; i++ {
		if _, err := m.createAndStartSlot(ctx, total+i+activeOrAssigned); err != nil {
			return err
		}
	}
	return nil
}

func (m *WarmPoolManager) createAndStartSlot(ctx context.Context, ordinal int) (ContainerInfo, error) {
	now := time.Now().UTC()
	slotID := fmt.Sprintf("slot-%03d-%d", ordinal+1, now.UnixNano())
	dsInstanceID := "ds_" + slotID
	name := fmt.Sprintf("%s-%s", m.config.DSContainerPrefix, slotID)
	hostBattlePort := 0
	if m.config.DSHostPortStart > 0 && m.config.DSHostPortEnd > m.config.DSHostPortStart {
		hostBattlePort = m.config.DSHostPortStart + (ordinal % (m.config.DSHostPortEnd - m.config.DSHostPortStart))
	}
	info, err := m.runtime.CreateWarmContainer(ctx, ContainerSpec{
		PoolID:         m.config.PoolID,
		SlotID:         slotID,
		DSInstanceID:   dsInstanceID,
		Name:           name,
		Image:          m.config.DSImage,
		NetworkName:    m.config.DSNetwork,
		Env:            m.config.ContainerEnv,
		AgentPort:      m.config.DSAgentPort,
		BattlePort:     m.config.DSBattlePort,
		HostBattlePort: hostBattlePort,
		Labels:         BuildLabels(m.config.PoolID, slotID, dsInstanceID, now),
	})
	if err != nil {
		return ContainerInfo{}, err
	}
	if err := m.runtime.StartContainer(ctx, info.ContainerID); err != nil {
		return ContainerInfo{}, err
	}
	return m.runtime.InspectContainer(ctx, info.ContainerID)
}
