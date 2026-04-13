package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPListenAddr           string
	PostgresDSN              string
	JWTSharedSecret          string
	InternalSharedSecret     string
	DefaultDSHost            string
	DefaultDSPort            int
	QueueHeartbeatTTLSeconds int
	CaptainDeadlineSeconds   int
	CommitDeadlineSeconds    int
	LogSQL                   bool
}

func LoadFromEnv() (*Config, error) {
	defaultDSPort, err := getRequiredPositiveInt("GAME_DEFAULT_DS_PORT", 9000)
	if err != nil {
		return nil, err
	}
	queueHeartbeatTTLSeconds, err := getRequiredPositiveInt("GAME_QUEUE_HEARTBEAT_TTL_SECONDS", 30)
	if err != nil {
		return nil, err
	}
	captainDeadlineSeconds, err := getRequiredPositiveInt("GAME_CAPTAIN_DEADLINE_SECONDS", 15)
	if err != nil {
		return nil, err
	}
	commitDeadlineSeconds, err := getRequiredPositiveInt("GAME_COMMIT_DEADLINE_SECONDS", 45)
	if err != nil {
		return nil, err
	}
	logSQL, err := getBool("GAME_LOG_SQL", false)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		HTTPListenAddr:           getEnv("GAME_HTTP_ADDR", "127.0.0.1:18081"),
		PostgresDSN:              os.Getenv("GAME_POSTGRES_DSN"),
		JWTSharedSecret:          os.Getenv("GAME_JWT_SHARED_SECRET"),
		InternalSharedSecret:     os.Getenv("GAME_INTERNAL_SHARED_SECRET"),
		DefaultDSHost:            getEnv("GAME_DEFAULT_DS_HOST", "127.0.0.1"),
		DefaultDSPort:            defaultDSPort,
		QueueHeartbeatTTLSeconds: queueHeartbeatTTLSeconds,
		CaptainDeadlineSeconds:   captainDeadlineSeconds,
		CommitDeadlineSeconds:    commitDeadlineSeconds,
		LogSQL:                   logSQL,
	}

	if cfg.HTTPListenAddr == "" {
		return nil, fmt.Errorf("GAME_HTTP_ADDR is required")
	}
	if cfg.PostgresDSN == "" {
		return nil, fmt.Errorf("GAME_POSTGRES_DSN is required")
	}
	if cfg.JWTSharedSecret == "" {
		return nil, fmt.Errorf("GAME_JWT_SHARED_SECRET is required")
	}
	if cfg.InternalSharedSecret == "" {
		return nil, fmt.Errorf("GAME_INTERNAL_SHARED_SECRET is required")
	}
	if cfg.DefaultDSHost == "" {
		return nil, fmt.Errorf("GAME_DEFAULT_DS_HOST is required")
	}

	return cfg, nil
}

func getEnv(key string, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getRequiredPositiveInt(key string, fallback int) (int, error) {
	value := os.Getenv(key)
	if value == "" {
		return fallback, nil
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be a valid integer: %w", key, err)
	}
	if parsed <= 0 {
		return 0, fmt.Errorf("%s must be > 0", key)
	}
	return parsed, nil
}

func getBool(key string, fallback bool) (bool, error) {
	value := os.Getenv(key)
	if value == "" {
		return fallback, nil
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return false, fmt.Errorf("%s must be a valid boolean: %w", key, err)
	}
	return parsed, nil
}
