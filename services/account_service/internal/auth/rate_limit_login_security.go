package auth

import (
	"context"
	"sync"
	"time"
)

// RateLimitLoginSecurityHooks implements LoginSecurityHooks with basic rate limiting.
// Production deployments should use Redis or similar for shared state.
type RateLimitLoginSecurityHooks struct {
	mu           sync.Mutex
	failures     map[string][]time.Time // keyed by "ip:"+RemoteAddr or "account:"+Account
	maxFailures  int
	windowPeriod time.Duration
	cooldown     time.Duration
}

// NewRateLimitLoginSecurityHooks creates a rate limiter that blocks after maxFailures
// within windowPeriod, with a cooldown before retry.
func NewRateLimitLoginSecurityHooks(maxFailures int, windowPeriod time.Duration, cooldown time.Duration) *RateLimitLoginSecurityHooks {
	return &RateLimitLoginSecurityHooks{
		failures:     make(map[string][]time.Time),
		maxFailures:  maxFailures,
		windowPeriod: windowPeriod,
		cooldown:     cooldown,
	}
}

func (h *RateLimitLoginSecurityHooks) CheckLoginAllowed(_ context.Context, input LoginSecurityDecisionInput) error {
	h.mu.Lock()
	defer h.mu.Unlock()

	now := time.Now().UTC()
	cutoff := now.Add(-h.windowPeriod)

	// Check by IP
	if input.RemoteAddr != "" {
		if blocked := h.isBlocked("ip:"+input.RemoteAddr, now, cutoff); blocked {
			return ErrLoginRateLimited
		}
	}
	// Check by account
	if input.Account != "" {
		if blocked := h.isBlocked("account:"+input.Account, now, cutoff); blocked {
			return ErrLoginRateLimited
		}
	}
	return nil
}

func (h *RateLimitLoginSecurityHooks) RecordLoginAttempt(_ context.Context, input LoginSecurityRecordInput) error {
	h.mu.Lock()
	defer h.mu.Unlock()

	if input.Succeeded {
		return nil
	}

	now := time.Now().UTC()
	if input.RemoteAddr != "" {
		h.failures["ip:"+input.RemoteAddr] = append(h.failures["ip:"+input.RemoteAddr], now)
	}
	if input.Account != "" {
		h.failures["account:"+input.Account] = append(h.failures["account:"+input.Account], now)
	}
	return nil
}

func (h *RateLimitLoginSecurityHooks) isBlocked(key string, now time.Time, cutoff time.Time) bool {
	events := h.failures[key]
	if len(events) == 0 {
		return false
	}
	// Prune old events
	var recent []time.Time
	for _, t := range events {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}
	h.failures[key] = recent

	if len(recent) >= h.maxFailures {
		// Check if we're still in cooldown after the last failure
		lastFailure := recent[len(recent)-1]
		if now.Before(lastFailure.Add(h.cooldown)) {
			return true
		}
		// Cooldown expired, reset
		h.failures[key] = nil
	}
	return false
}
