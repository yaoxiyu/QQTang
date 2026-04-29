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
		HTTPListenAddr:         env("DS_AGENT_HTTP_ADDR", "0.0.0.0:19090"),
		InternalAuthKeyID:      env("DS_AGENT_INTERNAL_AUTH_KEY_ID", env("QQT_INTERNAL_AUTH_KEY_ID", "primary")),
		InternalSharedSecret:   env("DS_AGENT_INTERNAL_AUTH_SHARED_SECRET", env("QQT_INTERNAL_AUTH_SECRET", os.Getenv("QQT_INTERNAL_SHARED_SECRET"))),
		InternalAuthMaxSkewSec: positiveInt("DS_AGENT_INTERNAL_AUTH_MAX_SKEW_SECONDS", 60),
		BattlePort:             positiveInt("DS_BATTLE_PORT", 9000),
		GodotExecutable:        env("DS_GODOT_EXECUTABLE", "/app/qqtang_battle_ds.x86_64"),
		ProjectRoot:            envAllowEmpty("DS_PROJECT_ROOT", "/app/project"),
		BattleScenePath:        envAllowEmpty("DS_BATTLE_SCENE_PATH", "res://scenes/network/dedicated_server_scene.tscn"),
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

func positiveInt(name string, fallback int) int {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}
