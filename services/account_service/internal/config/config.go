package config

import (
	"fmt"
	"os"

	"qqtang/services/account_service/internal/platform/configx"
)

type Config struct {
	HTTPListenAddr            string
	PostgresDSN               string
	AccessTokenTTLSeconds     int
	RefreshTokenTTLSeconds    int
	RoomTicketTTLSeconds      int
	BattleTicketTTLSeconds    int
	TokenSignSecret           string
	RoomTicketSignSecret      string
	BattleTicketSignSecret    string
	GameServiceBaseURL        string
	GameInternalAuthKeyID     string
	GameInternalSharedSecret  string
	GameInternalMaxSkewSec    int
	LoginRateLimitEnabled     bool
	LoginRateLimitMaxFails    int
	LoginRateLimitWindowSec   int
	LoginRateLimitCooldownSec int
	AllowMultiDevice          bool
	LogSQL                    bool
}

func LoadFromEnv() (*Config, error) {
	accessTokenTTLSeconds, err := configx.RequiredPositiveInt("ACCOUNT_ACCESS_TOKEN_TTL_SECONDS", 900)
	if err != nil {
		return nil, err
	}
	refreshTokenTTLSeconds, err := configx.RequiredPositiveInt("ACCOUNT_REFRESH_TOKEN_TTL_SECONDS", 14*24*60*60)
	if err != nil {
		return nil, err
	}
	roomTicketTTLSeconds, err := configx.RequiredPositiveInt("ACCOUNT_ROOM_TICKET_TTL_SECONDS", 60)
	if err != nil {
		return nil, err
	}
	battleTicketTTLSeconds, err := configx.RequiredPositiveInt("ACCOUNT_BATTLE_TICKET_TTL_SECONDS", 60)
	if err != nil {
		return nil, err
	}
	allowMultiDevice, err := configx.Bool("ACCOUNT_ALLOW_MULTI_DEVICE", false)
	if err != nil {
		return nil, err
	}
	logSQL, err := configx.Bool("ACCOUNT_LOG_SQL", false)
	if err != nil {
		return nil, err
	}
	gameInternalMaxSkewSec, err := configx.RequiredPositiveInt("ACCOUNT_GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS", 60)
	if err != nil {
		return nil, err
	}
	loginRateLimitEnabled, err := configx.Bool("ACCOUNT_LOGIN_RATE_LIMIT_ENABLED", true)
	if err != nil {
		return nil, err
	}
	loginRateLimitMaxFails, err := configx.RequiredPositiveInt("ACCOUNT_LOGIN_RATE_LIMIT_MAX_FAILURES", 5)
	if err != nil {
		return nil, err
	}
	loginRateLimitWindowSec, err := configx.RequiredPositiveInt("ACCOUNT_LOGIN_RATE_LIMIT_WINDOW_SECONDS", 60)
	if err != nil {
		return nil, err
	}
	loginRateLimitCooldownSec, err := configx.RequiredPositiveInt("ACCOUNT_LOGIN_RATE_LIMIT_COOLDOWN_SECONDS", 120)
	if err != nil {
		return nil, err
	}

	cfg := &Config{
		HTTPListenAddr:            configx.Env("ACCOUNT_HTTP_LISTEN_ADDR", "127.0.0.1:18080"),
		PostgresDSN:               os.Getenv("ACCOUNT_POSTGRES_DSN"),
		AccessTokenTTLSeconds:     accessTokenTTLSeconds,
		RefreshTokenTTLSeconds:    refreshTokenTTLSeconds,
		RoomTicketTTLSeconds:      roomTicketTTLSeconds,
		BattleTicketTTLSeconds:    battleTicketTTLSeconds,
		TokenSignSecret:           os.Getenv("ACCOUNT_TOKEN_SIGN_SECRET"),
		RoomTicketSignSecret:      os.Getenv("ACCOUNT_ROOM_TICKET_SIGN_SECRET"),
		BattleTicketSignSecret:    configx.Env("ACCOUNT_BATTLE_TICKET_SIGN_SECRET", "dev_battle_ticket_secret"),
		GameServiceBaseURL:        configx.Env("ACCOUNT_GAME_SERVICE_BASE_URL", "http://127.0.0.1:18081"),
		GameInternalAuthKeyID:     configx.Env("ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID", "primary"),
		GameInternalSharedSecret:  configx.Env("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET", os.Getenv("ACCOUNT_GAME_INTERNAL_SHARED_SECRET")),
		GameInternalMaxSkewSec:    gameInternalMaxSkewSec,
		LoginRateLimitEnabled:     loginRateLimitEnabled,
		LoginRateLimitMaxFails:    loginRateLimitMaxFails,
		LoginRateLimitWindowSec:   loginRateLimitWindowSec,
		LoginRateLimitCooldownSec: loginRateLimitCooldownSec,
		AllowMultiDevice:          allowMultiDevice,
		LogSQL:                    logSQL,
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
	if cfg.BattleTicketSignSecret == "" {
		return nil, fmt.Errorf("ACCOUNT_BATTLE_TICKET_SIGN_SECRET is required")
	}
	if cfg.GameServiceBaseURL == "" {
		return nil, fmt.Errorf("ACCOUNT_GAME_SERVICE_BASE_URL is required")
	}
	if cfg.GameInternalSharedSecret == "" {
		return nil, fmt.Errorf("ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET is required")
	}

	return cfg, nil
}
