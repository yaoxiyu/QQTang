package auth

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/account_service/internal/profile"
	"qqtang/services/account_service/internal/storage"
)

var (
	ErrAccountAlreadyExists  = errors.New("AUTH_ACCOUNT_ALREADY_EXISTS")
	ErrAccountInvalid        = errors.New("AUTH_ACCOUNT_INVALID")
	ErrPasswordInvalid       = errors.New("AUTH_PASSWORD_INVALID")
	ErrInvalidCredentials    = errors.New("AUTH_INVALID_CREDENTIALS")
	ErrAccountDisabled       = errors.New("AUTH_ACCOUNT_DISABLED")
	ErrAccountBanned         = errors.New("AUTH_ACCOUNT_BANNED")
	ErrRefreshTokenInvalid   = errors.New("AUTH_REFRESH_TOKEN_INVALID")
	ErrRefreshTokenExpired   = errors.New("AUTH_REFRESH_TOKEN_EXPIRED")
	ErrSessionRevoked        = errors.New("AUTH_SESSION_REVOKED")
	ErrDeviceSessionMismatch = errors.New("AUTH_DEVICE_SESSION_MISMATCH")
	ErrAccessTokenInvalid    = errors.New("AUTH_ACCESS_TOKEN_INVALID")
	ErrAccessTokenExpired    = errors.New("AUTH_ACCESS_TOKEN_EXPIRED")
)

type AuthService struct {
	pool            *pgxpool.Pool
	accountRepo     *storage.AccountRepository
	profileRepo     *storage.ProfileRepository
	sessionRepo     *storage.SessionRepository
	hasher          *PasswordHasher
	tokenIssuer     *TokenIssuer
	sessionService  *SessionService
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

type RegisterInput struct {
	Account        string
	Password       string
	Nickname       string
	ClientPlatform string
}

type LoginInput struct {
	Account        string
	Password       string
	ClientPlatform string
}

type RefreshInput struct {
	RefreshToken    string
	DeviceSessionID string
}

type LogoutInput struct {
	RefreshToken    string
	DeviceSessionID string
}

type AuthResult struct {
	SessionID              string `json:"-"`
	AccountID              string `json:"account_id"`
	ProfileID              string `json:"profile_id"`
	DisplayName            string `json:"display_name"`
	AuthMode               string `json:"auth_mode"`
	AccessToken            string `json:"access_token"`
	RefreshToken           string `json:"refresh_token"`
	DeviceSessionID        string `json:"device_session_id"`
	AccessExpireAtUnixSec  int64  `json:"access_expire_at_unix_sec"`
	RefreshExpireAtUnixSec int64  `json:"refresh_expire_at_unix_sec"`
	SessionState           string `json:"session_state"`
}

func NewAuthService(pool *pgxpool.Pool, accountRepo *storage.AccountRepository, profileRepo *storage.ProfileRepository, sessionRepo *storage.SessionRepository, hasher *PasswordHasher, tokenIssuer *TokenIssuer, sessionService *SessionService, accessTokenTTL time.Duration, refreshTokenTTL time.Duration) *AuthService {
	return &AuthService{
		pool:            pool,
		accountRepo:     accountRepo,
		profileRepo:     profileRepo,
		sessionRepo:     sessionRepo,
		hasher:          hasher,
		tokenIssuer:     tokenIssuer,
		sessionService:  sessionService,
		accessTokenTTL:  accessTokenTTL,
		refreshTokenTTL: refreshTokenTTL,
	}
}

func (s *AuthService) Register(ctx context.Context, input RegisterInput) (AuthResult, error) {
	account := strings.TrimSpace(input.Account)
	password := strings.TrimSpace(input.Password)
	nickname := strings.TrimSpace(input.Nickname)
	if account == "" {
		return AuthResult{}, ErrAccountInvalid
	}
	if password == "" {
		return AuthResult{}, ErrPasswordInvalid
	}
	if nickname == "" {
		return AuthResult{}, profile.ErrNicknameInvalid
	}
	if _, err := s.accountRepo.FindByLoginName(ctx, account); err == nil {
		return AuthResult{}, ErrAccountAlreadyExists
	} else if !errors.Is(err, storage.ErrNotFound) {
		return AuthResult{}, err
	}

	now := time.Now().UTC()
	accountID, err := s.tokenIssuer.IssueOpaqueToken("account")
	if err != nil {
		return AuthResult{}, err
	}
	profileID, err := s.tokenIssuer.IssueOpaqueToken("profile")
	if err != nil {
		return AuthResult{}, err
	}
	passwordHash, algo, err := s.hasher.HashPassword(password)
	if err != nil {
		return AuthResult{}, err
	}

	var result AuthResult
	err = s.runInTx(ctx, func(tx pgx.Tx) error {
		accountRepo := storage.NewAccountRepository(tx)
		profileRepo := storage.NewProfileRepository(tx)
		sessionRepo := storage.NewSessionRepository(tx)

		if err := accountRepo.Create(ctx, storage.Account{
			AccountID:    accountID,
			LoginName:    account,
			PasswordHash: passwordHash,
			PasswordAlgo: algo,
			Status:       "active",
			CreatedAt:    now,
			UpdatedAt:    now,
			LastLoginAt:  sql.NullTime{},
		}); err != nil {
			return err
		}
		if err := profileRepo.Create(ctx, storage.Profile{
			ProfileID:              profileID,
			AccountID:              accountID,
			Nickname:               nickname,
			DefaultCharacterID:     "char_huoying",
			DefaultCharacterSkinID: "skin_gold",
			DefaultBubbleStyleID:   "bubble_round",
			DefaultBubbleSkinID:    "bubble_skin_gold",
			ProfileVersion:         1,
			OwnedAssetRevision:     0,
			UpdatedAt:              now,
		}); err != nil {
			return err
		}

		defaultAssets := []storage.OwnedAsset{
			{AccountID: accountID, ProfileID: profileID, AssetType: "character", AssetID: "char_huoying", State: "owned", AcquiredAt: now, SourceType: "system"},
			{AccountID: accountID, ProfileID: profileID, AssetType: "character_skin", AssetID: "skin_gold", State: "owned", AcquiredAt: now, SourceType: "system"},
			{AccountID: accountID, ProfileID: profileID, AssetType: "bubble", AssetID: "bubble_round", State: "owned", AcquiredAt: now, SourceType: "system"},
			{AccountID: accountID, ProfileID: profileID, AssetType: "bubble_skin", AssetID: "bubble_skin_gold", State: "owned", AcquiredAt: now, SourceType: "system"},
		}
		for _, asset := range defaultAssets {
			if err := profileRepo.InsertOwnedAsset(ctx, asset); err != nil {
				return err
			}
		}

		issued, err := s.issueSessionWithRepo(ctx, sessionRepo, accountID, profileID, nickname, input.ClientPlatform, now)
		if err != nil {
			return err
		}
		result = issued
		return nil
	})
	if err != nil {
		if storage.IsConstraintViolation(err, "uq_accounts_login_name") {
			return AuthResult{}, ErrAccountAlreadyExists
		}
		return AuthResult{}, err
	}

	return result, nil
}

func (s *AuthService) Login(ctx context.Context, input LoginInput) (AuthResult, error) {
	account, err := s.accountRepo.FindByLoginName(ctx, strings.TrimSpace(input.Account))
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return AuthResult{}, ErrInvalidCredentials
		}
		return AuthResult{}, err
	}
	if !s.hasher.VerifyPassword(strings.TrimSpace(input.Password), account.PasswordHash, account.PasswordAlgo) {
		return AuthResult{}, ErrInvalidCredentials
	}
	switch account.Status {
	case "disabled":
		return AuthResult{}, ErrAccountDisabled
	case "banned":
		return AuthResult{}, ErrAccountBanned
	}

	profileRecord, err := s.profileRepo.FindByAccountID(ctx, account.AccountID)
	if err != nil {
		return AuthResult{}, err
	}

	now := time.Now().UTC()
	var result AuthResult
	err = s.runInTx(ctx, func(tx pgx.Tx) error {
		accountRepo := storage.NewAccountRepository(tx)
		sessionRepo := storage.NewSessionRepository(tx)

		if !s.sessionService.AllowMultiDevice() {
			if err := sessionRepo.RevokeAllActiveByAccountID(ctx, account.AccountID, now); err != nil {
				return err
			}
		}
		issued, err := s.issueSessionWithRepo(ctx, sessionRepo, account.AccountID, profileRecord.ProfileID, profileRecord.Nickname, input.ClientPlatform, now)
		if err != nil {
			return err
		}
		if err := accountRepo.UpdateLastLoginAt(ctx, account.AccountID, now); err != nil {
			return err
		}
		result = issued
		return nil
	})
	if err != nil {
		return AuthResult{}, err
	}

	return result, nil
}

func (s *AuthService) Refresh(ctx context.Context, input RefreshInput) (AuthResult, error) {
	session, err := s.sessionRepo.FindByRefreshHash(ctx, s.tokenIssuer.HashOpaqueToken(input.RefreshToken))
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return AuthResult{}, ErrRefreshTokenInvalid
		}
		return AuthResult{}, err
	}
	if session.RevokedAt.Valid {
		return AuthResult{}, ErrSessionRevoked
	}
	if !session.RefreshExpireAt.After(time.Now().UTC()) {
		return AuthResult{}, ErrRefreshTokenExpired
	}
	if input.DeviceSessionID != "" && input.DeviceSessionID != session.DeviceSessionID {
		return AuthResult{}, ErrDeviceSessionMismatch
	}

	profileRecord, err := s.profileRepo.FindByAccountID(ctx, session.AccountID)
	if err != nil {
		return AuthResult{}, err
	}

	now := time.Now().UTC()
	var result AuthResult
	err = s.runInTx(ctx, func(tx pgx.Tx) error {
		sessionRepo := storage.NewSessionRepository(tx)

		current, err := sessionRepo.FindBySessionID(ctx, session.SessionID)
		if err != nil {
			if errors.Is(err, storage.ErrNotFound) {
				return ErrRefreshTokenInvalid
			}
			return err
		}
		if current.RevokedAt.Valid {
			return ErrSessionRevoked
		}
		if !current.RefreshExpireAt.After(now) {
			return ErrRefreshTokenExpired
		}

		if err := sessionRepo.RevokeSessionByID(ctx, current.SessionID, now); err != nil {
			return err
		}
		issued, err := s.issueSessionWithRepoUsingDevice(ctx, sessionRepo, current.AccountID, profileRecord.ProfileID, profileRecord.Nickname, current.ClientPlatform, current.DeviceSessionID, now)
		if err != nil {
			return err
		}
		result = issued
		return nil
	})
	if err != nil {
		return AuthResult{}, err
	}

	return result, nil
}

func (s *AuthService) Logout(ctx context.Context, input LogoutInput) error {
	session, err := s.sessionRepo.FindByRefreshHash(ctx, s.tokenIssuer.HashOpaqueToken(input.RefreshToken))
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ErrRefreshTokenInvalid
		}
		return err
	}
	if input.DeviceSessionID != "" && input.DeviceSessionID != session.DeviceSessionID {
		return ErrDeviceSessionMismatch
	}
	if session.RevokedAt.Valid {
		return ErrSessionRevoked
	}
	return s.sessionRepo.RevokeSessionByID(ctx, session.SessionID, time.Now().UTC())
}

func (s *AuthService) ValidateAccessToken(ctx context.Context, accessToken string) (AuthResult, error) {
	claims, err := s.tokenIssuer.ParseAccessToken(accessToken)
	if err != nil {
		return AuthResult{}, ErrAccessTokenInvalid
	}
	now := time.Now().UTC()
	if s.tokenIssuer.IsExpired(claims.ExpiresAtUnixSec, now) {
		return AuthResult{}, ErrAccessTokenExpired
	}

	session, err := s.sessionRepo.FindBySessionID(ctx, claims.SessionID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return AuthResult{}, ErrAccessTokenInvalid
		}
		return AuthResult{}, err
	}
	if session.RevokedAt.Valid {
		return AuthResult{}, ErrSessionRevoked
	}
	if session.AccountID != claims.AccountID || session.DeviceSessionID != claims.DeviceSessionID {
		return AuthResult{}, ErrAccessTokenInvalid
	}
	if !session.AccessExpireAt.After(now) {
		return AuthResult{}, ErrAccessTokenExpired
	}

	profileRecord, err := s.profileRepo.FindByAccountID(ctx, claims.AccountID)
	if err != nil {
		return AuthResult{}, err
	}
	return AuthResult{
		SessionID:              claims.SessionID,
		AccountID:              claims.AccountID,
		ProfileID:              profileRecord.ProfileID,
		DisplayName:            profileRecord.Nickname,
		AuthMode:               claims.AuthMode,
		DeviceSessionID:        claims.DeviceSessionID,
		AccessExpireAtUnixSec:  claims.ExpiresAtUnixSec,
		RefreshExpireAtUnixSec: session.RefreshExpireAt.Unix(),
		SessionState:           "active",
	}, nil
}

func (s *AuthService) issueSessionWithRepo(ctx context.Context, sessionRepo *storage.SessionRepository, accountID string, profileID string, displayName string, clientPlatform string, now time.Time) (AuthResult, error) {
	deviceSessionID, err := s.tokenIssuer.IssueOpaqueToken("dsess")
	if err != nil {
		return AuthResult{}, err
	}
	return s.issueSessionWithRepoUsingDevice(ctx, sessionRepo, accountID, profileID, displayName, clientPlatform, deviceSessionID, now)
}

func (s *AuthService) issueSessionWithRepoUsingDevice(ctx context.Context, sessionRepo *storage.SessionRepository, accountID string, profileID string, displayName string, clientPlatform string, deviceSessionID string, now time.Time) (AuthResult, error) {
	sessionID, err := s.tokenIssuer.IssueOpaqueToken("sess")
	if err != nil {
		return AuthResult{}, err
	}
	refreshToken, err := s.tokenIssuer.IssueOpaqueToken("rtk")
	if err != nil {
		return AuthResult{}, err
	}

	accessExpireAt := now.Add(s.accessTokenTTL)
	refreshExpireAt := now.Add(s.refreshTokenTTL)
	accessToken, err := s.tokenIssuer.IssueAccessToken(AccessTokenClaims{
		SessionID:        sessionID,
		AccountID:        accountID,
		ProfileID:        profileID,
		DeviceSessionID:  deviceSessionID,
		AuthMode:         "password",
		DisplayName:      displayName,
		ExpiresAtUnixSec: accessExpireAt.Unix(),
	})
	if err != nil {
		return AuthResult{}, err
	}

	if err := sessionRepo.Create(ctx, storage.Session{
		SessionID:        sessionID,
		AccountID:        accountID,
		DeviceSessionID:  deviceSessionID,
		RefreshTokenHash: s.tokenIssuer.HashOpaqueToken(refreshToken),
		ClientPlatform:   strings.TrimSpace(clientPlatform),
		IssuedAt:         now,
		AccessExpireAt:   accessExpireAt,
		RefreshExpireAt:  refreshExpireAt,
		LastSeenAt:       now,
	}); err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		SessionID:              sessionID,
		AccountID:              accountID,
		ProfileID:              profileID,
		DisplayName:            displayName,
		AuthMode:               "password",
		AccessToken:            accessToken,
		RefreshToken:           refreshToken,
		DeviceSessionID:        deviceSessionID,
		AccessExpireAtUnixSec:  accessExpireAt.Unix(),
		RefreshExpireAtUnixSec: refreshExpireAt.Unix(),
		SessionState:           "active",
	}, nil
}

func (s *AuthService) runInTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}

	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}

	return tx.Commit(ctx)
}
