package config

import (
	"fmt"

	"qqtang/services/ds_manager_service/internal/platform/configx"
)

type Config struct {
	HTTPListenAddr string

	// Godot battle DS process settings
	GodotExecutable string
	ProjectRoot     string
	BattleScenePath string
	BattleTicketSecret string

	// Port pool range for battle DS instances
	PortRangeStart int
	PortRangeEnd   int

	// DS host address reported to clients
	DSHost string

	// Health check / reap settings
	ReadyTimeoutSec    int
	IdleReapTimeoutSec int
}

func LoadFromEnv() (*Config, error) {
	cfg := &Config{}

	cfg.HTTPListenAddr = configx.Env("DSM_HTTP_ADDR", "127.0.0.1:18090")

	cfg.GodotExecutable = configx.Env("DSM_GODOT_EXECUTABLE", "godot4")
	cfg.ProjectRoot = configx.Env("DSM_PROJECT_ROOT", "")
	cfg.BattleScenePath = configx.Env("DSM_BATTLE_SCENE_PATH", "res://scenes/network/dedicated_server_scene.tscn")
	cfg.BattleTicketSecret = configx.Env("DSM_BATTLE_TICKET_SECRET", "dev_battle_ticket_secret")

	cfg.DSHost = configx.Env("DSM_DS_HOST", "127.0.0.1")

	var err error

	cfg.PortRangeStart, err = configx.RequiredPositiveInt("DSM_PORT_RANGE_START", 19010)
	if err != nil {
		return nil, fmt.Errorf("DSM_PORT_RANGE_START: %w", err)
	}

	cfg.PortRangeEnd, err = configx.RequiredPositiveInt("DSM_PORT_RANGE_END", 19050)
	if err != nil {
		return nil, fmt.Errorf("DSM_PORT_RANGE_END: %w", err)
	}

	if cfg.PortRangeEnd <= cfg.PortRangeStart {
		return nil, fmt.Errorf("DSM_PORT_RANGE_END (%d) must be > DSM_PORT_RANGE_START (%d)", cfg.PortRangeEnd, cfg.PortRangeStart)
	}

	cfg.ReadyTimeoutSec, err = configx.RequiredPositiveInt("DSM_READY_TIMEOUT_SEC", 15)
	if err != nil {
		return nil, fmt.Errorf("DSM_READY_TIMEOUT_SEC: %w", err)
	}

	cfg.IdleReapTimeoutSec, err = configx.RequiredPositiveInt("DSM_IDLE_REAP_TIMEOUT_SEC", 300)
	if err != nil {
		return nil, fmt.Errorf("DSM_IDLE_REAP_TIMEOUT_SEC: %w", err)
	}

	return cfg, nil
}
