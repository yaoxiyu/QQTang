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

	// Runtime pool settings
	PoolMode                   string
	PoolID                     string
	PoolMinReady               int
	PoolMaxSize                int
	PoolPrefillBatch           int
	PoolReconcileIntervalSec   int
	AllocateWaitReadyTimeoutMS int
	DockerSocket               string
	DSImage                    string
	DSNetwork                  string
	DSContainerPrefix          string
	DSAgentPort                int
	DSBattlePort               int
	DSAdvertiseMode            string
	DSPublicHost               string
	DSHostPortRangeStart       int
	DSHostPortRangeEnd         int
	DSAgentInternalAuthKeyID   string
	DSAgentInternalAuthSecret  string
	GameServiceBaseURL         string
	DSMBaseURL                 string

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

	cfg.PoolMode = configx.Env("DSM_POOL_MODE", "local_process_legacy")
	cfg.PoolID = configx.Env("DSM_POOL_ID", "default")
	cfg.PoolMinReady, err = configx.RequiredPositiveInt("DSM_POOL_MIN_READY", 1)
	if err != nil {
		return nil, fmt.Errorf("DSM_POOL_MIN_READY: %w", err)
	}
	cfg.PoolMaxSize, err = configx.RequiredPositiveInt("DSM_POOL_MAX_SIZE", 4)
	if err != nil {
		return nil, fmt.Errorf("DSM_POOL_MAX_SIZE: %w", err)
	}
	if cfg.PoolMaxSize < cfg.PoolMinReady {
		return nil, fmt.Errorf("DSM_POOL_MAX_SIZE (%d) must be >= DSM_POOL_MIN_READY (%d)", cfg.PoolMaxSize, cfg.PoolMinReady)
	}
	cfg.PoolPrefillBatch, err = configx.RequiredPositiveInt("DSM_POOL_PREFILL_BATCH", 1)
	if err != nil {
		return nil, fmt.Errorf("DSM_POOL_PREFILL_BATCH: %w", err)
	}
	cfg.PoolReconcileIntervalSec, err = configx.RequiredPositiveInt("DSM_POOL_RECONCILE_INTERVAL_SEC", 5)
	if err != nil {
		return nil, fmt.Errorf("DSM_POOL_RECONCILE_INTERVAL_SEC: %w", err)
	}
	cfg.AllocateWaitReadyTimeoutMS, err = configx.RequiredPositiveInt("DSM_ALLOCATE_WAIT_READY_TIMEOUT_MS", 5000)
	if err != nil {
		return nil, fmt.Errorf("DSM_ALLOCATE_WAIT_READY_TIMEOUT_MS: %w", err)
	}
	cfg.DockerSocket = configx.Env("DSM_DOCKER_SOCKET", "unix:///var/run/docker.sock")
	cfg.DSImage = configx.Env("DSM_DS_IMAGE", "qqtang/battle-ds:dev")
	cfg.DSNetwork = configx.Env("DSM_DS_NETWORK", "")
	cfg.DSContainerPrefix = configx.Env("DSM_DS_CONTAINER_PREFIX", "qqt-ds")
	cfg.DSAgentPort, err = configx.RequiredPositiveInt("DSM_DS_AGENT_PORT", 19090)
	if err != nil {
		return nil, fmt.Errorf("DSM_DS_AGENT_PORT: %w", err)
	}
	cfg.DSBattlePort, err = configx.RequiredPositiveInt("DSM_DS_BATTLE_PORT", 9000)
	if err != nil {
		return nil, fmt.Errorf("DSM_DS_BATTLE_PORT: %w", err)
	}
	cfg.DSAdvertiseMode = configx.Env("DSM_DS_ADVERTISE_MODE", "container_name")
	cfg.DSPublicHost = configx.Env("DSM_DS_PUBLIC_HOST", "")
	cfg.DSHostPortRangeStart, err = configx.RequiredPositiveInt("DSM_DS_HOST_PORT_RANGE_START", 20000)
	if err != nil {
		return nil, fmt.Errorf("DSM_DS_HOST_PORT_RANGE_START: %w", err)
	}
	cfg.DSHostPortRangeEnd, err = configx.RequiredPositiveInt("DSM_DS_HOST_PORT_RANGE_END", 20100)
	if err != nil {
		return nil, fmt.Errorf("DSM_DS_HOST_PORT_RANGE_END: %w", err)
	}
	if cfg.DSHostPortRangeEnd <= cfg.DSHostPortRangeStart {
		return nil, fmt.Errorf("DSM_DS_HOST_PORT_RANGE_END (%d) must be > DSM_DS_HOST_PORT_RANGE_START (%d)", cfg.DSHostPortRangeEnd, cfg.DSHostPortRangeStart)
	}
	cfg.DSAgentInternalAuthKeyID = configx.Env("DSM_DS_AGENT_INTERNAL_AUTH_KEY_ID", cfg.InternalAuthKeyID)
	cfg.DSAgentInternalAuthSecret = configx.Env("DSM_DS_AGENT_INTERNAL_AUTH_SECRET", cfg.InternalSharedSecret)
	cfg.GameServiceBaseURL = configx.Env("DSM_GAME_SERVICE_BASE_URL", "http://game_service:18081")
	cfg.DSMBaseURL = configx.Env("DSM_BASE_URL", "http://ds_manager_service:18090")

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
