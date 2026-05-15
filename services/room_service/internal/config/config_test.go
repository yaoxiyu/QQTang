package config

import "testing"

func TestLoadFromEnvRejectsMultiReplicaInProduction(t *testing.T) {
	t.Setenv("ROOM_ENV", "production")
	t.Setenv("ROOM_HTTP_ADDR", "0.0.0.0:19100")
	t.Setenv("ROOM_WS_ADDR", "0.0.0.0:9100")
	t.Setenv("ROOM_MANIFEST_PATH", "manifest.json")
	t.Setenv("ROOM_TICKET_SECRET", "room_ticket_prod_secure_secret")
	t.Setenv("ROOM_ALLOWED_ORIGINS", "https://example.com")
	t.Setenv("ROOM_EXPECTED_REPLICAS", "2")

	_, err := LoadFromEnv()
	if err == nil {
		t.Fatal("expected production multi-replica config to be rejected")
	}
}

func TestLoadFromEnvRejectsNonSingleDeploymentModeInProduction(t *testing.T) {
	t.Setenv("ROOM_ENV", "production")
	t.Setenv("ROOM_HTTP_ADDR", "0.0.0.0:19100")
	t.Setenv("ROOM_WS_ADDR", "0.0.0.0:9100")
	t.Setenv("ROOM_MANIFEST_PATH", "manifest.json")
	t.Setenv("ROOM_TICKET_SECRET", "room_ticket_prod_secure_secret")
	t.Setenv("ROOM_ALLOWED_ORIGINS", "https://example.com")
	t.Setenv("ROOM_DEPLOYMENT_MODE", "multi_instance")

	_, err := LoadFromEnv()
	if err == nil {
		t.Fatal("expected production multi-instance mode to be rejected")
	}
}

func TestLoadFromEnvAllowsDevMultiReplicaForConvenience(t *testing.T) {
	t.Setenv("ROOM_ENV", "development")
	t.Setenv("ROOM_HTTP_ADDR", "127.0.0.1:19100")
	t.Setenv("ROOM_WS_ADDR", "127.0.0.1:9100")
	t.Setenv("ROOM_MANIFEST_PATH", "manifest.json")
	t.Setenv("ROOM_TICKET_SECRET", "dev_room_ticket_secret")
	t.Setenv("ROOM_EXPECTED_REPLICAS", "3")
	t.Setenv("ROOM_DEPLOYMENT_MODE", "multi_instance")

	cfg, err := LoadFromEnv()
	if err != nil {
		t.Fatalf("expected dev config to pass, got err=%v", err)
	}
	if cfg.RoomExpectedReplicas != 3 {
		t.Fatalf("unexpected replicas: got=%d", cfg.RoomExpectedReplicas)
	}
}
