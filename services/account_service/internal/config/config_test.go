package config

import (
	"strings"
	"testing"
)

func TestLoadFromEnvSuccess(t *testing.T) {
	t.Setenv("ACCOUNT_HTTP_LISTEN_ADDR", "127.0.0.1:19090")
	t.Setenv("ACCOUNT_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("ACCOUNT_ACCESS_TOKEN_TTL_SECONDS", "120")
	t.Setenv("ACCOUNT_REFRESH_TOKEN_TTL_SECONDS", "240")
	t.Setenv("ACCOUNT_ROOM_TICKET_TTL_SECONDS", "30")
	t.Setenv("ACCOUNT_TOKEN_SIGN_SECRET", "access-secret")
	t.Setenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET", "ticket-secret")
	t.Setenv("ACCOUNT_BATTLE_TICKET_SIGN_SECRET", "battle-ticket-secret")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID", "test-key")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS", "45")
	t.Setenv("ACCOUNT_ALLOW_MULTI_DEVICE", "true")
	t.Setenv("ACCOUNT_LOG_SQL", "true")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv returned error: %v", err)
	}

	if cfg.HTTPListenAddr != "127.0.0.1:19090" {
		t.Fatalf("unexpected listen addr: %s", cfg.HTTPListenAddr)
	}
	if cfg.PostgresDSN == "" || cfg.TokenSignSecret == "" || cfg.RoomTicketSignSecret == "" || cfg.BattleTicketSignSecret == "" {
		t.Fatalf("expected required secrets and dsn to be set: %+v", cfg)
	}
	if cfg.AccessTokenTTLSeconds != 120 || cfg.RefreshTokenTTLSeconds != 240 || cfg.RoomTicketTTLSeconds != 30 {
		t.Fatalf("unexpected ttl values: %+v", cfg)
	}
	if !cfg.AllowMultiDevice || !cfg.LogSQL {
		t.Fatalf("expected bool flags to be true: %+v", cfg)
	}
	if cfg.GameInternalAuthKeyID != "test-key" || cfg.GameInternalSharedSecret != "internal-secret" || cfg.GameInternalMaxSkewSec != 45 {
		t.Fatalf("unexpected internal auth config: %+v", cfg)
	}
}

func TestLoadFromEnvRejectsInvalidInt(t *testing.T) {
	setMinimumValidEnv(t)
	t.Setenv("ACCOUNT_ACCESS_TOKEN_TTL_SECONDS", "oops")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "ACCOUNT_ACCESS_TOKEN_TTL_SECONDS") {
		t.Fatalf("expected invalid ttl error, got: %v", err)
	}
}

func TestLoadFromEnvRejectsInvalidBool(t *testing.T) {
	setMinimumValidEnv(t)
	t.Setenv("ACCOUNT_ALLOW_MULTI_DEVICE", "not-a-bool")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "ACCOUNT_ALLOW_MULTI_DEVICE") {
		t.Fatalf("expected invalid bool error, got: %v", err)
	}
}

func TestLoadFromEnvRejectsMissingRequiredFields(t *testing.T) {
	setMinimumValidEnv(t)
	t.Setenv("ACCOUNT_POSTGRES_DSN", "")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "ACCOUNT_POSTGRES_DSN is required") {
		t.Fatalf("expected missing dsn error, got: %v", err)
	}
}

func setMinimumValidEnv(t *testing.T) {
	t.Helper()

	t.Setenv("ACCOUNT_HTTP_LISTEN_ADDR", "127.0.0.1:18080")
	t.Setenv("ACCOUNT_POSTGRES_DSN", "postgres://tester:pass@127.0.0.1:5432/test_db?sslmode=disable")
	t.Setenv("ACCOUNT_ACCESS_TOKEN_TTL_SECONDS", "900")
	t.Setenv("ACCOUNT_REFRESH_TOKEN_TTL_SECONDS", "1209600")
	t.Setenv("ACCOUNT_ROOM_TICKET_TTL_SECONDS", "60")
	t.Setenv("ACCOUNT_TOKEN_SIGN_SECRET", "access-secret")
	t.Setenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET", "ticket-secret")
	t.Setenv("ACCOUNT_BATTLE_TICKET_SIGN_SECRET", "battle-ticket-secret")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID", "primary")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS", "60")
	t.Setenv("ACCOUNT_ALLOW_MULTI_DEVICE", "false")
	t.Setenv("ACCOUNT_LOG_SQL", "false")
}
