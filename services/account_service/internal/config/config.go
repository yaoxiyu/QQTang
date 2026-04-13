package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPListenAddr         string
	PostgresDSN            string
	AccessTokenTTLSeconds  int
	RefreshTokenTTLSeconds int
	RoomTicketTTLSeconds   int
	TokenSignSecret        string
	RoomTicketSignSecret   string
	AllowMultiDevice       bool
	LogSQL                 bool
}

func LoadFromEnv() (*Config, error) {
	accessTokenTTLSeconds, err := getRequiredPositiveInt("ACCOUNT_ACCESS_TOKEN_TTL_SECONDS", 900)
	if err != nil {
		return nil, err
	}
	refreshTokenTTLSeconds, err := getRequiredPositiveInt("ACCOUNT_REFRESH_TOKEN_TTL_SECONDS", 14*24*60*60)
	if err != nil {
		return nil, err
	}
	roomTicketTTLSeconds, err := getRequiredPositiveInt("ACCOUNT_ROOM_TICKET_TTL_SECONDS", 60)
	if err != nil {
		return nil, err
	}
	allowMultiDevice, err := getBool("ACCOUNT_ALLOW_MULTI_DEVICE", false)
	if err != nil {
		return nil, err
	}
	logSQL, err := getBool("ACCOUNT_LOG_SQL", false)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		HTTPListenAddr:         getEnv("ACCOUNT_HTTP_LISTEN_ADDR", "127.0.0.1:18080"),
		PostgresDSN:            os.Getenv("ACCOUNT_POSTGRES_DSN"),
		AccessTokenTTLSeconds:  accessTokenTTLSeconds,
		RefreshTokenTTLSeconds: refreshTokenTTLSeconds,
		RoomTicketTTLSeconds:   roomTicketTTLSeconds,
		TokenSignSecret:        os.Getenv("ACCOUNT_TOKEN_SIGN_SECRET"),
		RoomTicketSignSecret:   os.Getenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET"),
		AllowMultiDevice:       allowMultiDevice,
		LogSQL:                 logSQL,
	}

	if cfg.HTTPListenAddr == "" {
		return nil, fmt.Errorf("ACCOUNT_HTTP_LISTEN_ADDR is required")
	}
	if cfg.PostgresDSN == "" {
		return nil, fmt.Errorf("ACCOUNT_POSTGRES_DSN is required")
	}
	if cfg.TokenSignSecret == "" {
		return nil, fmt.Errorf("ACCOUNT_TOKEN_SIGN_SECRET is required")
	}
	if cfg.RoomTicketSignSecret == "" {
		return nil, fmt.Errorf("ACCOUNT_ROOM_TICKET_SIGN_SECRET is required")
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
