package config

import (
	"strings"
	"testing"

	"qqtang/services/game_service/internal/queue"
)

func TestLoadFromEnvInternalAuthConfig(t *testing.T) {
	t.Setenv("GAME_HTTP_ADDR", "127.0.0.1:19091")
	t.Setenv("GAME_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("GAME_JWT_SHARED_SECRET", "jwt-secret")
	t.Setenv("GAME_INTERNAL_AUTH_KEY_ID", "test-key")
	t.Setenv("GAME_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS", "45")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv returned error: %v", err)
	}
	if cfg.InternalAuthKeyID != "test-key" || cfg.InternalSharedSecret != "internal-secret" || cfg.InternalAuthMaxSkewSec != 45 {
		t.Fatalf("unexpected internal auth config: %+v", cfg)
	}
	if cfg.DefaultSeasonID != queue.DefaultSeasonID || cfg.DefaultMapID != queue.DefaultMapID || cfg.DefaultDSHost != queue.DefaultDSHost || cfg.DefaultDSPort != queue.DefaultDSPort {
		t.Fatalf("unexpected assignment defaults: %+v", cfg)
	}
}

func TestLoadFromEnvAssignmentDefaultsOverride(t *testing.T) {
	t.Setenv("GAME_HTTP_ADDR", "127.0.0.1:19091")
	t.Setenv("GAME_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("GAME_JWT_SHARED_SECRET", "jwt-secret")
	t.Setenv("GAME_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("GAME_DEFAULT_SEASON_ID", "season_test")
	t.Setenv("GAME_DEFAULT_MAP_ID", "map_test")
	t.Setenv("GAME_DEFAULT_DS_HOST", "10.0.0.8")
	t.Setenv("GAME_DEFAULT_DS_PORT", "19000")
	t.Setenv("GAME_QUEUE_HEARTBEAT_TTL_SECONDS", "31")
	t.Setenv("GAME_CAPTAIN_DEADLINE_SECONDS", "16")
	t.Setenv("GAME_COMMIT_DEADLINE_SECONDS", "46")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv returned error: %v", err)
	}
	if cfg.DefaultSeasonID != "season_test" || cfg.DefaultMapID != "map_test" || cfg.DefaultDSHost != "10.0.0.8" || cfg.DefaultDSPort != 19000 {
		t.Fatalf("unexpected assignment defaults: %+v", cfg)
	}
	if cfg.QueueHeartbeatTTLSeconds != 31 || cfg.CaptainDeadlineSeconds != 16 || cfg.CommitDeadlineSeconds != 46 {
		t.Fatalf("unexpected matchmaking durations: %+v", cfg)
	}
}

func TestLoadFromEnvRejectsMissingInternalAuthSecret(t *testing.T) {
	t.Setenv("GAME_HTTP_ADDR", "127.0.0.1:19091")
	t.Setenv("GAME_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("GAME_JWT_SHARED_SECRET", "jwt-secret")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "GAME_INTERNAL_AUTH_SHARED_SECRET is required") {
		t.Fatalf("expected missing internal auth secret error, got: %v", err)
	}
}

func TestLoadFromEnvRejectsDevSecretsInProduction(t *testing.T) {
	t.Setenv("GAME_ENV", "production")
	t.Setenv("GAME_HTTP_ADDR", "127.0.0.1:19091")
	t.Setenv("GAME_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("GAME_JWT_SHARED_SECRET", "dev_jwt_secret")
	t.Setenv("GAME_INTERNAL_AUTH_SHARED_SECRET", "dev_internal_shared_secret")

	_, err := LoadFromEnv()
	if err == nil {
		t.Fatal("expected production config with dev secrets to be rejected")
	}
}

func TestLoadFromEnvAllowsDevSecretsInDevelopment(t *testing.T) {
	t.Setenv("GAME_ENV", "development")
	t.Setenv("GAME_HTTP_ADDR", "127.0.0.1:19091")
	t.Setenv("GAME_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("GAME_JWT_SHARED_SECRET", "dev_jwt_secret")
	t.Setenv("GAME_INTERNAL_AUTH_SHARED_SECRET", "dev_internal_shared_secret")

	if _, err := LoadFromEnv(); err != nil {
		t.Fatalf("expected development config to pass, got %v", err)
	}
}
