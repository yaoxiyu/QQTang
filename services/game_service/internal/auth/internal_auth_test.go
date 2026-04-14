package auth

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"qqtang/services/game_service/internal/internalhttp"
)

func TestInternalAuthValidateRequest(t *testing.T) {
	auth := NewInternalAuth("primary", "shared-secret", time.Minute)
	req := signedInternalRequest(t, http.MethodPost, "/internal/v1/matches/finalize?match_id=m1", []byte(`{"ok":true}`), "primary", "shared-secret", time.Now())

	if err := auth.ValidateRequest(req); err != nil {
		t.Fatalf("ValidateRequest returned error: %v", err)
	}
	restored := make([]byte, len(`{"ok":true}`))
	if _, err := req.Body.Read(restored); err != nil {
		t.Fatalf("read restored body: %v", err)
	}
	if string(restored) != `{"ok":true}` {
		t.Fatalf("expected body to be restored, got %q", string(restored))
	}
}

func TestInternalAuthRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*http.Request)
		now    time.Time
	}{
		{
			name: "missing header",
			mutate: func(req *http.Request) {
				req.Header.Del(internalhttp.HeaderSignature)
			},
			now: time.Now(),
		},
		{
			name: "wrong signature",
			mutate: func(req *http.Request) {
				req.Header.Set(internalhttp.HeaderSignature, "bad-signature")
			},
			now: time.Now(),
		},
		{
			name: "expired timestamp",
			now:  time.Now().Add(-2 * time.Minute),
		},
		{
			name: "body hash mismatch",
			mutate: func(req *http.Request) {
				req.Body = http.NoBody
			},
			now: time.Now(),
		},
		{
			name: "unknown key id",
			mutate: func(req *http.Request) {
				req.Header.Set(internalhttp.HeaderKeyID, "secondary")
			},
			now: time.Now(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := signedInternalRequest(t, http.MethodPost, "/internal/v1/matches/finalize", []byte(`{"ok":true}`), "primary", "shared-secret", tt.now)
			if tt.mutate != nil {
				tt.mutate(req)
			}
			auth := NewInternalAuth("primary", "shared-secret", time.Minute)
			if err := auth.ValidateRequest(req); err == nil {
				t.Fatal("expected invalid internal auth")
			}
		})
	}
}

func TestInternalAuthRejectsNonceReplay(t *testing.T) {
	auth := NewInternalAuth("primary", "shared-secret", time.Minute)
	req := signedInternalRequest(t, http.MethodGet, "/internal/v1/assignments/a1/grant", nil, "primary", "shared-secret", time.Now())
	if err := auth.ValidateRequest(req); err != nil {
		t.Fatalf("first ValidateRequest returned error: %v", err)
	}
	replay := signedInternalRequest(t, http.MethodGet, "/internal/v1/assignments/a1/grant", nil, "primary", "shared-secret", time.Now())
	copyInternalHeaders(replay.Header, req.Header)
	if err := auth.ValidateRequest(replay); err == nil {
		t.Fatal("expected replayed nonce to be rejected")
	}
}

func signedInternalRequest(t *testing.T, method string, target string, body []byte, keyID string, secret string, now time.Time) *http.Request {
	t.Helper()
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	timestamp := strconvFormatUnix(now)
	nonce := "nonce-" + timestamp
	bodyHash := internalhttp.BodySHA256Hex(body)
	signature := internalhttp.Sign(method, req.URL.RequestURI(), timestamp, nonce, bodyHash, secret)
	req.Header.Set(internalhttp.HeaderKeyID, keyID)
	req.Header.Set(internalhttp.HeaderTimestamp, timestamp)
	req.Header.Set(internalhttp.HeaderNonce, nonce)
	req.Header.Set(internalhttp.HeaderBodySHA256, bodyHash)
	req.Header.Set(internalhttp.HeaderSignature, signature)
	return req
}

func copyInternalHeaders(dst http.Header, src http.Header) {
	for _, key := range []string{
		internalhttp.HeaderKeyID,
		internalhttp.HeaderTimestamp,
		internalhttp.HeaderNonce,
		internalhttp.HeaderBodySHA256,
		internalhttp.HeaderSignature,
	} {
		dst.Set(key, src.Get(key))
	}
}

func strconvFormatUnix(t time.Time) string {
	return strconv.FormatInt(t.UTC().Unix(), 10)
}
