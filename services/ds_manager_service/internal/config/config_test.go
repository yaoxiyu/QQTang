package config

import (
	"strings"
	"testing"
)

func TestLoadFromEnvInternalAuthConfig(t *testing.T) {
	t.Setenv("DSM_HTTP_ADDR", "127.0.0.1:18090")
	t.Setenv("DSM_INTERNAL_AUTH_KEY_ID", "test-key")
	t.Setenv("DSM_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS", "45")
	t.Setenv("DSM_PORT_RANGE_START", "19010")
	t.Setenv("DSM_PORT_RANGE_END", "19050")
	t.Setenv("DSM_READY_TIMEOUT_SEC", "15")
	t.Setenv("DSM_IDLE_REAP_TIMEOUT_SEC", "300")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv returned error: %v", err)
	}
	if cfg.InternalAuthKeyID != "test-key" || cfg.InternalSharedSecret != "internal-secret" || cfg.InternalAuthMaxSkewSec != 45 {
		t.Fatalf("unexpected internal auth config: %+v", cfg)
	}
}

func TestLoadFromEnvRejectsMissingInternalAuthSecret(t *testing.T) {
	t.Setenv("DSM_INTERNAL_AUTH_SHARED_SECRET", "")
	t.Setenv("DSM_INTERNAL_SHARED_SECRET", "")
	t.Setenv("DSM_PORT_RANGE_START", "19010")
	t.Setenv("DSM_PORT_RANGE_END", "19050")
	t.Setenv("DSM_READY_TIMEOUT_SEC", "15")
	t.Setenv("DSM_IDLE_REAP_TIMEOUT_SEC", "300")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "DSM_INTERNAL_AUTH_SHARED_SECRET is required") {
		t.Fatalf("expected missing internal auth secret error, got %v", err)
	}
}
