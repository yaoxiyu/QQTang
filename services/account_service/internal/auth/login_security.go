package auth

import (
	"context"
	"errors"
	"time"
)

var (
	ErrLoginRateLimited = errors.New("AUTH_LOGIN_RATE_LIMITED")
	ErrCaptchaRequired  = errors.New("AUTH_CAPTCHA_REQUIRED")
	ErrLoginRiskBlocked = errors.New("AUTH_LOGIN_RISK_BLOCKED")
)

type LoginSecurityDecisionInput struct {
	Account        string
	ClientPlatform string
	RemoteAddr     string
	UserAgent      string
	CaptchaToken   string
	AttemptedAt    time.Time
}

type LoginSecurityRecordInput struct {
	Account        string
	AccountID      string
	ClientPlatform string
	RemoteAddr     string
	UserAgent      string
	AttemptedAt    time.Time
	Succeeded      bool
	FailureReason  string
}

type LoginSecurityHooks interface {
	CheckLoginAllowed(ctx context.Context, input LoginSecurityDecisionInput) error
	RecordLoginAttempt(ctx context.Context, input LoginSecurityRecordInput) error
}

type noopLoginSecurityHooks struct{}

func NewNoopLoginSecurityHooks() LoginSecurityHooks {
	return noopLoginSecurityHooks{}
}

func (noopLoginSecurityHooks) CheckLoginAllowed(context.Context, LoginSecurityDecisionInput) error {
	return nil
}

func (noopLoginSecurityHooks) RecordLoginAttempt(context.Context, LoginSecurityRecordInput) error {
	return nil
}

func failureReason(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}
