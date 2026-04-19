package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	RoomHTTPAddr            string
	RoomWSAddr              string
	RoomDefaultPort         int
	RoomTicketSecret        string
	RoomManifestPath        string
	RoomGameServiceGRPCAddr string
	RoomInstanceID          string
	RoomShardID             string
	RoomLogLevel            string
	RoomEnv                 string
	RoomAllowedOrigins      []string
}

func LoadFromEnv() (*Config, error) {
	defaultPort, err := positiveInt("ROOM_DEFAULT_PORT", 9100)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		RoomHTTPAddr:            envOr("ROOM_HTTP_ADDR", "127.0.0.1:19100"),
		RoomWSAddr:              envOr("ROOM_WS_ADDR", fmt.Sprintf("127.0.0.1:%d", defaultPort)),
		RoomDefaultPort:         defaultPort,
		RoomTicketSecret:        envOr("ROOM_TICKET_SECRET", "dev_room_ticket_secret"),
		RoomManifestPath:        envOr("ROOM_MANIFEST_PATH", "../../build/generated/room_manifest/room_manifest.json"),
		RoomGameServiceGRPCAddr: envOr("ROOM_GAME_SERVICE_GRPC_ADDR", "127.0.0.1:19081"),
		RoomInstanceID:          envOr("ROOM_INSTANCE_ID", "room-instance-dev"),
		RoomShardID:             envOr("ROOM_SHARD_ID", "room-shard-dev"),
		RoomLogLevel:            envOr("ROOM_LOG_LEVEL", "info"),
		RoomEnv:                 envOr("ROOM_ENV", "development"),
		RoomAllowedOrigins:      parseCSV(envOr("ROOM_ALLOWED_ORIGINS", "")),
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

	return cfg, nil
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
