package config

import "testing"

func TestLoadFromEnvRejectsDevSecretsInProduction(t *testing.T) {
	t.Setenv("ACCOUNT_ENV", "production")
	t.Setenv("ACCOUNT_HTTP_LISTEN_ADDR", "0.0.0.0:18080")
	t.Setenv("ACCOUNT_POSTGRES_DSN", "postgres://user:pass@localhost:5432/db")
	t.Setenv("ACCOUNT_TOKEN_SIGN_SECRET", "token_prod_secret")
	t.Setenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET", "dev_room_ticket_secret")
	t.Setenv("ACCOUNT_BATTLE_TICKET_SIGN_SECRET", "dev_battle_ticket_secret")
	t.Setenv("ACCOUNT_GAME_SERVICE_BASE_URL", "http://game:18081")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET", "services_internal_shared_secret")

	_, err := LoadFromEnv()
	if err == nil {
		t.Fatal("expected production config with dev secret to be rejected")
	}
}

func TestLoadFromEnvAllowsDevDefaultsInDevelopment(t *testing.T) {
	t.Setenv("ACCOUNT_ENV", "development")
	t.Setenv("ACCOUNT_HTTP_LISTEN_ADDR", "127.0.0.1:18080")
	t.Setenv("ACCOUNT_POSTGRES_DSN", "postgres://user:pass@localhost:5432/db")
	t.Setenv("ACCOUNT_TOKEN_SIGN_SECRET", "token_dev_secret")
	t.Setenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET", "dev_room_ticket_secret")
	t.Setenv("ACCOUNT_BATTLE_TICKET_SIGN_SECRET", "dev_battle_ticket_secret")
	t.Setenv("ACCOUNT_GAME_SERVICE_BASE_URL", "http://127.0.0.1:18081")
	t.Setenv("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET", "dev_internal_shared_secret")

	if _, err := LoadFromEnv(); err != nil {
		t.Fatalf("expected development config to pass, got err=%v", err)
	}
}
