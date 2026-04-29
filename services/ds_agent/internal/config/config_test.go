package config

import "testing"

func TestLoadFromEnvPreservesEmptyBattleScenePath(t *testing.T) {
	t.Setenv("DS_AGENT_INTERNAL_AUTH_SHARED_SECRET", "secret")
	t.Setenv("DS_BATTLE_SCENE_PATH", "")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv failed: %v", err)
	}

	if cfg.BattleScenePath != "" {
		t.Fatalf("expected empty battle scene path, got %q", cfg.BattleScenePath)
	}
}
