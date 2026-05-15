package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	RoomHTTPAddr                       string
	RoomWSAddr                         string
	RoomDefaultPort                    int
	RoomTicketSecret                   string
	RoomManifestPath                   string
	RoomGameServiceGRPCAddr            string
	RoomGameServiceBaseURL             string
	RoomGameInternalAuthKeyID          string
	RoomGameInternalAuthSecret         string
	RoomEmptyBattleCleanupGraceSeconds int
	RoomInstanceID                     string
	RoomShardID                        string
	RoomLogLevel                       string
	RoomEnv                            string
	RoomAllowedOrigins                 []string
	RoomAllowAllOrigins                bool
	RoomWSMaxFrameBytes                int
	RoomWSReadTimeoutSeconds           int
	RoomWSPingIntervalSeconds          int
	RoomDeploymentMode                 string
	RoomExpectedReplicas               int
}

func LoadFromEnv() (*Config, error) {
	defaultPort, err := positiveInt("ROOM_DEFAULT_PORT", 9100)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		RoomHTTPAddr:               envOr("ROOM_HTTP_ADDR", "127.0.0.1:19100"),
		RoomWSAddr:                 envOr("ROOM_WS_ADDR", fmt.Sprintf("127.0.0.1:%d", defaultPort)),
		RoomDefaultPort:            defaultPort,
		RoomTicketSecret:           envOr("ROOM_TICKET_SECRET", "dev_room_ticket_secret"),
		RoomManifestPath:           envOr("ROOM_MANIFEST_PATH", "../../build/generated/room_manifest/room_manifest.json"),
		RoomGameServiceGRPCAddr:    envOr("ROOM_GAME_SERVICE_GRPC_ADDR", "127.0.0.1:19081"),
		RoomGameServiceBaseURL:     envOr("ROOM_GAME_SERVICE_BASE_URL", ""),
		RoomGameInternalAuthKeyID:  envOr("ROOM_GAME_INTERNAL_AUTH_KEY_ID", "primary"),
		RoomGameInternalAuthSecret: envOr("ROOM_GAME_INTERNAL_AUTH_SHARED_SECRET", ""),
		RoomInstanceID:             envOr("ROOM_INSTANCE_ID", "room-instance-dev"),
		RoomShardID:                envOr("ROOM_SHARD_ID", "room-shard-dev"),
		RoomLogLevel:               envOr("ROOM_LOG_LEVEL", "info"),
		RoomEnv:                    envOr("ROOM_ENV", "development"),
		RoomAllowAllOrigins:        envBoolOr("ROOM_ALLOW_ALL_ORIGINS", false),
		RoomAllowedOrigins:         parseCSV(envOr("ROOM_ALLOWED_ORIGINS", "")),
		RoomDeploymentMode:         envOr("ROOM_DEPLOYMENT_MODE", "single_instance"),
	}
	cfg.RoomExpectedReplicas, err = positiveInt("ROOM_EXPECTED_REPLICAS", 1)
	if err != nil {
		return nil, err
	}
	cfg.RoomEmptyBattleCleanupGraceSeconds, err = positiveInt("ROOM_EMPTY_BATTLE_CLEANUP_GRACE_SECONDS", 30)
	if err != nil {
		return nil, err
	}
	cfg.RoomWSMaxFrameBytes, err = positiveInt("ROOM_WS_MAX_FRAME_BYTES", 65536)
	if err != nil {
		return nil, err
	}
	cfg.RoomWSReadTimeoutSeconds, err = positiveInt("ROOM_WS_READ_TIMEOUT_SECONDS", 30)
	if err != nil {
		return nil, err
	}
	cfg.RoomWSPingIntervalSeconds, err = positiveInt("ROOM_WS_PING_INTERVAL_SECONDS", 10)
	if err != nil {
		return nil, err
	}

	if cfg.RoomHTTPAddr == "" {
		return nil, fmt.Errorf("ROOM_HTTP_ADDR is required")
	}
	if cfg.RoomWSAddr == "" {
		return nil, fmt.Errorf("ROOM_WS_ADDR is required")
	}
	if cfg.RoomManifestPath == "" {
		return nil, fmt.Errorf("ROOM_MANIFEST_PATH is required")
	}
	if cfg.RoomTicketSecret == "" {
		return nil, fmt.Errorf("ROOM_TICKET_SECRET is required")
	}
	if isProductionEnv(cfg.RoomEnv) && len(cfg.RoomAllowedOrigins) == 0 {
		return nil, fmt.Errorf("ROOM_ALLOWED_ORIGINS is required in production")
	}
	if isProductionEnv(cfg.RoomEnv) && cfg.RoomAllowAllOrigins {
		return nil, fmt.Errorf("ROOM_ALLOW_ALL_ORIGINS must be false in production")
	}
	if isProductionEnv(cfg.RoomEnv) && isUnsafeDevSecret(cfg.RoomTicketSecret) {
		return nil, fmt.Errorf("ROOM_TICKET_SECRET uses unsafe development secret in production")
	}
	if isProductionEnv(cfg.RoomEnv) && strings.TrimSpace(strings.ToLower(cfg.RoomDeploymentMode)) != "single_instance" {
		return nil, fmt.Errorf("ROOM_DEPLOYMENT_MODE must be single_instance in production until persistent room state is enabled")
	}
	if isProductionEnv(cfg.RoomEnv) && cfg.RoomExpectedReplicas > 1 {
		return nil, fmt.Errorf("ROOM_EXPECTED_REPLICAS must be 1 in production until persistent room state is enabled")
	}

	return cfg, nil
}

func envBoolOr(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	b, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return b
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func positiveInt(key string, fallback int) (int, error) {
	value := envOr(key, "")
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return 0, fmt.Errorf("%s must be a positive integer", key)
	}
	return parsed, nil
}

func parseCSV(value string) []string {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func isProductionEnv(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "prod", "production":
		return true
	default:
		return false
	}
}

var unsafeSecretPatterns = []string{
	"dev_",
	"replace_me",
	"changeme",
	"qqtang_dev_pass",
}

func isUnsafeDevSecret(secret string) bool {
	lower := strings.ToLower(strings.TrimSpace(secret))
	if lower == "" {
		return true
	}
	for _, pattern := range unsafeSecretPatterns {
		if strings.Contains(lower, pattern) {
			return true
		}
	}
	return false
}
