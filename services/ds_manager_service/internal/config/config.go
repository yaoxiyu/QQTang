package config

import (
	"fmt"
	"os"
	"path/filepath"

	"qqtang/services/ds_manager_service/internal/platform/configx"
)

type Config struct {
	HTTPListenAddr         string
	InternalAuthKeyID      string
	InternalSharedSecret   string
	InternalAuthMaxSkewSec int

	// Godot battle DS process settings
	GodotExecutable    string
	ProjectRoot        string
	BattleScenePath    string
	BattleTicketSecret string
	BattleLogDir       string

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
	var err error

	cfg.HTTPListenAddr = configx.Env("DSM_HTTP_ADDR", "127.0.0.1:18090")
	cfg.InternalAuthKeyID = configx.Env("DSM_INTERNAL_AUTH_KEY_ID", "primary")
	cfg.InternalSharedSecret = configx.Env("DSM_INTERNAL_AUTH_SHARED_SECRET", os.Getenv("DSM_INTERNAL_SHARED_SECRET"))
	cfg.InternalAuthMaxSkewSec, err = configx.RequiredPositiveInt("DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS", 60)
	if err != nil {
		return nil, fmt.Errorf("DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS: %w", err)
	}

	cfg.GodotExecutable = configx.Env("DSM_GODOT_EXECUTABLE", "godot4")
	cfg.ProjectRoot = configx.Env("DSM_PROJECT_ROOT", "")
	cfg.BattleScenePath = configx.Env("DSM_BATTLE_SCENE_PATH", "res://scenes/network/dedicated_server_scene.tscn")
	cfg.BattleTicketSecret = configx.Env("DSM_BATTLE_TICKET_SECRET", "dev_battle_ticket_secret")
	cfg.BattleLogDir = configx.Env("DSM_BATTLE_LOG_DIR", "")

	cfg.DSHost = configx.Env("DSM_DS_HOST", "127.0.0.1")

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

	if cfg.BattleLogDir == "" {
		cfg.BattleLogDir = defaultBattleLogDir(cfg.ProjectRoot)
	}
	if cfg.InternalSharedSecret == "" {
		return nil, fmt.Errorf("DSM_INTERNAL_AUTH_SHARED_SECRET is required")
	}

	return cfg, nil
}

func defaultBattleLogDir(projectRoot string) string {
	if projectRoot == "" {
		if resolved, ok := findProjectRoot(); ok {
			projectRoot = resolved
		}
	}
	if projectRoot == "" {
		return ""
	}
	return filepath.Join(projectRoot, "logs", "battle_ds")
}

func findProjectRoot() (string, bool) {
	wd, err := os.Getwd()
	if err != nil {
		return "", false
	}
	dir := wd
	for {
		if _, err := os.Stat(filepath.Join(dir, "project.godot")); err == nil {
			return dir, true
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", false
		}
		dir = parent
	}
}
