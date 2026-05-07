package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPListenAddr         string
	InternalAuthKeyID      string
	InternalSharedSecret   string
	InternalAuthMaxSkewSec int
	BattlePort             int
	GodotExecutable        string
	ProjectRoot            string
	BattleScenePath        string
}

func LoadFromEnv() (*Config, error) {
	cfg := &Config{
		HTTPListenAddr:       env("DS_AGENT_HTTP_ADDR", "0.0.0.0:19090"),
		InternalAuthKeyID:    env("DS_AGENT_INTERNAL_AUTH_KEY_ID", env("QQT_INTERNAL_AUTH_KEY_ID", "primary")),
		InternalSharedSecret: env("DS_AGENT_INTERNAL_AUTH_SHARED_SECRET", env("QQT_INTERNAL_AUTH_SECRET", os.Getenv("QQT_INTERNAL_SHARED_SECRET"))),
		GodotExecutable:      env("DS_GODOT_EXECUTABLE", "/app/qqtang_battle_ds.x86_64"),
		ProjectRoot:          envAllowEmpty("DS_PROJECT_ROOT", "/app/project"),
		BattleScenePath:      envAllowEmpty("DS_BATTLE_SCENE_PATH", "res://scenes/network/dedicated_server_scene.tscn"),
	}

	var err error
	cfg.InternalAuthMaxSkewSec, err = positiveInt("DS_AGENT_INTERNAL_AUTH_MAX_SKEW_SECONDS", 60)
	if err != nil {
		return nil, fmt.Errorf("DS_AGENT_INTERNAL_AUTH_MAX_SKEW_SECONDS: %w", err)
	}
	cfg.BattlePort, err = positiveInt("DS_BATTLE_PORT", 9000)
	if err != nil {
		return nil, fmt.Errorf("DS_BATTLE_PORT: %w", err)
	}

	if cfg.InternalSharedSecret == "" {
		return nil, fmt.Errorf("DS_AGENT_INTERNAL_AUTH_SHARED_SECRET is required")
	}
	return cfg, nil
}

func env(name string, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func envAllowEmpty(name string, fallback string) string {
	value, ok := os.LookupEnv(name)
	if ok {
		return value
	}
	return fallback
}

func positiveInt(name string, fallback int) (int, error) {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("%s must be a valid integer: %w", name, err)
	}
	if value <= 0 {
		return 0, fmt.Errorf("%s must be > 0 (got %d)", name, value)
	}
	return value, nil
}
