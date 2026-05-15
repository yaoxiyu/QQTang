package config

import (
	"fmt"
	"os"
	"strings"

	"qqtang/services/game_service/internal/platform/configx"
	"qqtang/services/game_service/internal/queue"
)

type Config struct {
	HTTPListenAddr           string
	GRPCListenAddr           string
	PostgresDSN              string
	JWTSharedSecret          string
	InternalAuthKeyID        string
	InternalSharedSecret     string
	InternalAuthMaxSkewSec   int
	DefaultSeasonID          string
	DefaultMapID             string
	RoomManifestPath         string
	DefaultDSHost            string
	DefaultDSPort            int
	QueueHeartbeatTTLSeconds int
	CaptainDeadlineSeconds   int
	CommitDeadlineSeconds    int
	LogSQL                   bool
	GameEnv                  string

	// DS Manager Service URL
	DSManagerURL string
}

func LoadFromEnv() (*Config, error) {
	defaultDSPort, err := configx.RequiredPositiveInt("GAME_DEFAULT_DS_PORT", queue.DefaultDSPort)
	if err != nil {
		return nil, err
	}
	queueHeartbeatTTLSeconds, err := configx.RequiredPositiveInt("GAME_QUEUE_HEARTBEAT_TTL_SECONDS", queue.DefaultQueueHeartbeatSeconds)
	if err != nil {
		return nil, err
	}
	captainDeadlineSeconds, err := configx.RequiredPositiveInt("GAME_CAPTAIN_DEADLINE_SECONDS", queue.DefaultCaptainDeadlineSeconds)
	if err != nil {
		return nil, err
	}
	commitDeadlineSeconds, err := configx.RequiredPositiveInt("GAME_COMMIT_DEADLINE_SECONDS", queue.DefaultCommitDeadlineSeconds)
	if err != nil {
		return nil, err
	}
	logSQL, err := configx.Bool("GAME_LOG_SQL", false)
	if err != nil {
		return nil, err
	}
	internalAuthMaxSkewSec, err := configx.RequiredPositiveInt("GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS", 60)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		HTTPListenAddr:           configx.Env("GAME_HTTP_ADDR", "127.0.0.1:18081"),
		GRPCListenAddr:           configx.Env("GAME_GRPC_ADDR", "127.0.0.1:19081"),
		PostgresDSN:              os.Getenv("GAME_POSTGRES_DSN"),
		JWTSharedSecret:          os.Getenv("GAME_JWT_SHARED_SECRET"),
		InternalAuthKeyID:        configx.Env("GAME_INTERNAL_AUTH_KEY_ID", "primary"),
		InternalSharedSecret:     configx.Env("GAME_INTERNAL_AUTH_SHARED_SECRET", os.Getenv("GAME_INTERNAL_SHARED_SECRET")),
		InternalAuthMaxSkewSec:   internalAuthMaxSkewSec,
		DefaultSeasonID:          configx.Env("GAME_DEFAULT_SEASON_ID", queue.DefaultSeasonID),
		DefaultMapID:             configx.Env("GAME_DEFAULT_MAP_ID", queue.DefaultMapID),
		RoomManifestPath:         configx.Env("GAME_ROOM_MANIFEST_PATH", "../../build/generated/room_manifest/room_manifest.json"),
		DefaultDSHost:            configx.Env("GAME_DEFAULT_DS_HOST", queue.DefaultDSHost),
		DefaultDSPort:            defaultDSPort,
		QueueHeartbeatTTLSeconds: queueHeartbeatTTLSeconds,
		CaptainDeadlineSeconds:   captainDeadlineSeconds,
		CommitDeadlineSeconds:    commitDeadlineSeconds,
		LogSQL:                   logSQL,
		GameEnv:                  configx.Env("GAME_ENV", "development"),

		// Room/Battle process split
		DSManagerURL: configx.Env("GAME_DS_MANAGER_URL", "http://127.0.0.1:18090"),
	}

	if cfg.HTTPListenAddr == "" {
		return nil, fmt.Errorf("GAME_HTTP_ADDR is required")
	}
	if cfg.GRPCListenAddr == "" {
		return nil, fmt.Errorf("GAME_GRPC_ADDR is required")
	}
	if cfg.PostgresDSN == "" {
		return nil, fmt.Errorf("GAME_POSTGRES_DSN is required")
	}
	if cfg.JWTSharedSecret == "" {
		return nil, fmt.Errorf("GAME_JWT_SHARED_SECRET is required")
	}
	if cfg.InternalSharedSecret == "" {
		return nil, fmt.Errorf("GAME_INTERNAL_AUTH_SHARED_SECRET is required")
	}
	if cfg.DefaultDSHost == "" {
		return nil, fmt.Errorf("GAME_DEFAULT_DS_HOST is required")
	}
	if cfg.DefaultSeasonID == "" {
		return nil, fmt.Errorf("GAME_DEFAULT_SEASON_ID is required")
	}
	if cfg.DefaultMapID == "" {
		return nil, fmt.Errorf("GAME_DEFAULT_MAP_ID is required")
	}
	if cfg.RoomManifestPath == "" {
		return nil, fmt.Errorf("GAME_ROOM_MANIFEST_PATH is required")
	}
	if isProductionEnv(cfg.GameEnv) && isUnsafeDevSecret(cfg.JWTSharedSecret) {
		return nil, fmt.Errorf("GAME_JWT_SHARED_SECRET uses unsafe development secret in production")
	}
	if isProductionEnv(cfg.GameEnv) && isUnsafeDevSecret(cfg.InternalSharedSecret) {
		return nil, fmt.Errorf("GAME_INTERNAL_AUTH_SHARED_SECRET uses unsafe development secret in production")
	}

	return cfg, nil
}

func isProductionEnv(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "prod", "production":
		return true
	default:
		return false
	}
}

func isUnsafeDevSecret(secret string) bool {
	lower := strings.ToLower(strings.TrimSpace(secret))
	if lower == "" {
		return true
	}
	for _, pattern := range []string{"dev_", "replace_me", "changeme", "qqtang_dev_pass"} {
		if strings.Contains(lower, pattern) {
			return true
		}
	}
	return false
}
