package auth

import (
	"context"
	"time"

	"qqtang/services/account_service/internal/storage"
)

type SessionService struct {
	sessionRepo      *storage.SessionRepository
	allowMultiDevice bool
}

func NewSessionService(sessionRepo *storage.SessionRepository, allowMultiDevice bool) *SessionService {
	return &SessionService{
		sessionRepo:      sessionRepo,
		allowMultiDevice: allowMultiDevice,
	}
}

func (s *SessionService) RevokeOtherSessions(ctx context.Context, accountID string, now time.Time) error {
	if s.allowMultiDevice {
		return nil
	}
	return s.sessionRepo.RevokeAllActiveByAccountID(ctx, accountID, now)
}

func (s *SessionService) AllowMultiDevice() bool {
	return s.allowMultiDevice
}
