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
	if cfg.PoolMode != "local_process_legacy" {
		t.Fatalf("unexpected default pool mode: %s", cfg.PoolMode)
	}
}

func TestLoadFromEnvRuntimePoolDefaults(t *testing.T) {
	t.Setenv("DSM_INTERNAL_AUTH_SHARED_SECRET", "internal-secret")
	t.Setenv("DSM_PORT_RANGE_START", "19010")
	t.Setenv("DSM_PORT_RANGE_END", "19050")
	t.Setenv("DSM_READY_TIMEOUT_SEC", "15")
	t.Setenv("DSM_IDLE_REAP_TIMEOUT_SEC", "300")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("LoadFromEnv returned error: %v", err)
	}

	if cfg.PoolMode != "local_process_legacy" {
		t.Fatalf("PoolMode = %q", cfg.PoolMode)
	}
	if cfg.PoolID != "default" {
		t.Fatalf("PoolID = %q", cfg.PoolID)
	}
	if cfg.PoolMinReady != 1 || cfg.PoolMaxSize != 4 || cfg.PoolPrefillBatch != 1 {
		t.Fatalf("unexpected pool size defaults: %+v", cfg)
	}
	if cfg.PoolReconcileIntervalSec != 5 || cfg.AllocateWaitReadyTimeoutMS != 5000 {
		t.Fatalf("unexpected pool timing defaults: %+v", cfg)
	}
	if cfg.DockerSocket != "unix:///var/run/docker.sock" {
		t.Fatalf("DockerSocket = %q", cfg.DockerSocket)
	}
	if cfg.DSImage != "qqtang/battle-ds:dev" || cfg.DSContainerPrefix != "qqt-ds" {
		t.Fatalf("unexpected DS image/prefix defaults: %+v", cfg)
	}
	if cfg.DSAgentPort != 19090 || cfg.DSBattlePort != 9000 {
		t.Fatalf("unexpected DS ports: %+v", cfg)
	}
	if cfg.DSAdvertiseMode != "container_name" {
		t.Fatalf("DSAdvertiseMode = %q", cfg.DSAdvertiseMode)
	}
	if cfg.DSHostPortRangeStart != 20000 || cfg.DSHostPortRangeEnd != 20100 {
		t.Fatalf("unexpected host port range: %+v", cfg)
	}
	if cfg.DSAgentInternalAuthKeyID != "primary" || cfg.DSAgentInternalAuthSecret != "internal-secret" {
		t.Fatalf("unexpected ds agent auth defaults: %+v", cfg)
	}
	if cfg.GameServiceBaseURL != "http://game_service:18081" || cfg.DSMBaseURL != "http://ds_manager_service:18090" {
		t.Fatalf("unexpected service base urls: %+v", cfg)
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

func TestLoadFromEnvRejectsDockerPoolInProduction(t *testing.T) {
	t.Setenv("DSM_ENV", "production")
	t.Setenv("DSM_INTERNAL_AUTH_SHARED_SECRET", "prod_internal_shared_secret")
	t.Setenv("DSM_BATTLE_TICKET_SECRET", "prod_battle_ticket_secret")
	t.Setenv("DSM_POOL_MODE", "docker_warm_pool")
	t.Setenv("DSM_DOCKER_SOCKET", "unix:///var/run/docker.sock")
	t.Setenv("DSM_PORT_RANGE_START", "19010")
	t.Setenv("DSM_PORT_RANGE_END", "19050")
	t.Setenv("DSM_READY_TIMEOUT_SEC", "15")
	t.Setenv("DSM_IDLE_REAP_TIMEOUT_SEC", "300")

	_, err := LoadFromEnv()
	if err == nil || !strings.Contains(err.Error(), "docker variants are not allowed in production") {
		t.Fatalf("expected docker pool production rejection, got %v", err)
	}
}

func TestLoadFromEnvAllowsDockerPoolInDevelopment(t *testing.T) {
	t.Setenv("DSM_ENV", "development")
	t.Setenv("DSM_INTERNAL_AUTH_SHARED_SECRET", "dev_internal_shared_secret")
	t.Setenv("DSM_BATTLE_TICKET_SECRET", "dev_battle_ticket_secret")
	t.Setenv("DSM_POOL_MODE", "docker_warm_pool")
	t.Setenv("DSM_DOCKER_SOCKET", "unix:///var/run/docker.sock")
	t.Setenv("DSM_PORT_RANGE_START", "19010")
	t.Setenv("DSM_PORT_RANGE_END", "19050")
	t.Setenv("DSM_READY_TIMEOUT_SEC", "15")
	t.Setenv("DSM_IDLE_REAP_TIMEOUT_SEC", "300")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("expected development docker pool config to pass, got %v", err)
	}
	if cfg.PoolMode != "docker_warm_pool" {
		t.Fatalf("unexpected pool mode: %s", cfg.PoolMode)
	}
}
