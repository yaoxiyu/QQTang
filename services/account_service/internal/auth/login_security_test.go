package auth

import (
	"context"
	"testing"
	"time"
)

type blockingLoginSecurityHooks struct {
	seen LoginSecurityDecisionInput
}

func (h *blockingLoginSecurityHooks) CheckLoginAllowed(_ context.Context, input LoginSecurityDecisionInput) error {
	h.seen = input
	return ErrCaptchaRequired
}

func (h *blockingLoginSecurityHooks) RecordLoginAttempt(context.Context, LoginSecurityRecordInput) error {
	return nil
}

func TestLoginSecurityHookCanBlockBeforeRepositoryAccess(t *testing.T) {
	hooks := &blockingLoginSecurityHooks{}
	service := NewAuthService(nil, nil, nil, nil, nil, nil, nil, time.Minute, time.Hour, WithLoginSecurityHooks(hooks))

	_, err := service.Login(context.Background(), LoginInput{
		Account:        " player_one ",
		Password:       "secret",
		ClientPlatform: "windows",
		RemoteAddr:     "127.0.0.1:12345",
		UserAgent:      "QQTangTest/1.0",
		CaptchaToken:   "captcha-token",
	})
	if err != ErrCaptchaRequired {
		t.Fatalf("expected captcha error, got %v", err)
	}
	if hooks.seen.Account != "player_one" {
		t.Fatalf("expected trimmed account, got %q", hooks.seen.Account)
	}
	if hooks.seen.RemoteAddr != "127.0.0.1:12345" || hooks.seen.UserAgent != "QQTangTest/1.0" || hooks.seen.CaptchaToken != "captcha-token" {
		t.Fatalf("login security context was not forwarded: %+v", hooks.seen)
	}
	if hooks.seen.AttemptedAt.IsZero() {
		t.Fatalf("expected attempted timestamp")
	}
}
