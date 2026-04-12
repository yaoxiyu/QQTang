package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	HTTPListenAddr   string
	PostgresDSN      string
	TokenSecret      string
	RoomTicketSecret string
	AccessTokenTTL   time.Duration
	RefreshTokenTTL  time.Duration
	RoomTicketTTL    time.Duration
}

func LoadFromEnv() (Config, error) {
	cfg := Config{
		HTTPListenAddr:   getEnv("ACCOUNT_SERVICE_LISTEN_ADDR", ":8080"),
		PostgresDSN:      os.Getenv("ACCOUNT_SERVICE_POSTGRES_DSN"),
		TokenSecret:      os.Getenv("ACCOUNT_SERVICE_TOKEN_SECRET"),
		RoomTicketSecret: getEnv("ACCOUNT_SERVICE_ROOM_TICKET_SECRET", os.Getenv("ACCOUNT_SERVICE_TOKEN_SECRET")),
		AccessTokenTTL:   getEnvDurationSeconds("ACCOUNT_SERVICE_ACCESS_TOKEN_TTL_SEC", 15*60),
		RefreshTokenTTL:  getEnvDurationSeconds("ACCOUNT_SERVICE_REFRESH_TOKEN_TTL_SEC", 30*24*60*60),
		RoomTicketTTL:    getEnvDurationSeconds("ACCOUNT_SERVICE_ROOM_TICKET_TTL_SEC", 45),
	}
	if cfg.PostgresDSN == "" {
		return Config{}, fmt.Errorf("ACCOUNT_SERVICE_POSTGRES_DSN is required")
	}
	if cfg.TokenSecret == "" {
		return Config{}, fmt.Errorf("ACCOUNT_SERVICE_TOKEN_SECRET is required")
	}
	if cfg.RoomTicketSecret == "" {
		return Config{}, fmt.Errorf("ACCOUNT_SERVICE_ROOM_TICKET_SECRET is required")
	}
	return cfg, nil
}

func getEnv(key string, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvDurationSeconds(key string, fallback int) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return time.Duration(fallback) * time.Second
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return time.Duration(fallback) * time.Second
	}
	return time.Duration(parsed) * time.Second
}
