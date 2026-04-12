package storage

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

type Session struct {
	SessionID        string
	AccountID        string
	DeviceSessionID  string
	RefreshTokenHash string
	ClientPlatform   string
	IssuedAt         time.Time
	AccessExpireAt   time.Time
	RefreshExpireAt  time.Time
	RevokedAt        sql.NullTime
	LastSeenAt       time.Time
}

type SessionRepository struct {
	db *sql.DB
}

func NewSessionRepository(db *sql.DB) *SessionRepository {
	return &SessionRepository{db: db}
}

func (r *SessionRepository) Create(ctx context.Context, session Session) error {
	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO account_sessions (
			session_id,
			account_id,
			device_session_id,
			refresh_token_hash,
			client_platform,
			issued_at,
			access_expire_at,
			refresh_expire_at,
			revoked_at,
			last_seen_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		session.SessionID,
		session.AccountID,
		session.DeviceSessionID,
		session.RefreshTokenHash,
		session.ClientPlatform,
		session.IssuedAt,
		session.AccessExpireAt,
		session.RefreshExpireAt,
		session.RevokedAt,
		session.LastSeenAt,
	)
	return err
}

func (r *SessionRepository) FindByRefreshHash(ctx context.Context, refreshHash string) (Session, error) {
	row := r.db.QueryRowContext(
		ctx,
		`SELECT
			session_id,
			account_id,
			device_session_id,
			refresh_token_hash,
			client_platform,
			issued_at,
			access_expire_at,
			refresh_expire_at,
			revoked_at,
			last_seen_at
		FROM account_sessions
		WHERE refresh_token_hash = $1`,
		refreshHash,
	)
	return scanSession(row)
}

func (r *SessionRepository) RevokeSessionByID(ctx context.Context, sessionID string, revokedAt time.Time) error {
	_, err := r.db.ExecContext(
		ctx,
		`UPDATE account_sessions
		SET revoked_at = $2,
			last_seen_at = $2
		WHERE session_id = $1`,
		sessionID,
		revokedAt,
	)
	return err
}

func (r *SessionRepository) RevokeAllActiveByAccountID(ctx context.Context, accountID string, revokedAt time.Time) error {
	_, err := r.db.ExecContext(
		ctx,
		`UPDATE account_sessions
		SET revoked_at = $2,
			last_seen_at = $2
		WHERE account_id = $1
			AND revoked_at IS NULL`,
		accountID,
		revokedAt,
	)
	return err
}

func (r *SessionRepository) UpdateRotatedTokens(ctx context.Context, session Session) error {
	_, err := r.db.ExecContext(
		ctx,
		`UPDATE account_sessions
		SET refresh_token_hash = $2,
			access_expire_at = $3,
			refresh_expire_at = $4,
			last_seen_at = $5
		WHERE session_id = $1`,
		session.SessionID,
		session.RefreshTokenHash,
		session.AccessExpireAt,
		session.RefreshExpireAt,
		session.LastSeenAt,
	)
	return err
}

func scanSession(scanner interface{ Scan(dest ...any) error }) (Session, error) {
	var session Session
	err := scanner.Scan(
		&session.SessionID,
		&session.AccountID,
		&session.DeviceSessionID,
		&session.RefreshTokenHash,
		&session.ClientPlatform,
		&session.IssuedAt,
		&session.AccessExpireAt,
		&session.RefreshExpireAt,
		&session.RevokedAt,
		&session.LastSeenAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return Session{}, ErrNotFound
	}
	return session, err
}
