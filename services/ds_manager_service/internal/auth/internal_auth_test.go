package auth

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/internalhttp"
)

func TestInternalAuthValidateRequest(t *testing.T) {
	auth := NewInternalAuth("primary", "shared-secret", time.Minute)
	body := []byte(`{"battle_id":"battle_a"}`)
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/battles/allocate?x=1", bytes.NewReader(body))
	signRequest(t, req, body, "primary", "shared-secret", time.Now().UTC())

	if err := auth.ValidateRequest(req); err != nil {
		t.Fatalf("ValidateRequest returned error: %v", err)
	}
}

func TestInternalAuthRejectsMissingOrBadHeaders(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name       string
		mutateFunc func(req *http.Request)
	}{
		{
			name: "missing signature",
			mutateFunc: func(req *http.Request) {
				req.Header.Del(internalhttp.HeaderSignature)
			},
		},
		{
			name: "wrong key id",
			mutateFunc: func(req *http.Request) {
				req.Header.Set(internalhttp.HeaderKeyID, "secondary")
			},
		},
		{
			name: "bad signature",
			mutateFunc: func(req *http.Request) {
				req.Header.Set(internalhttp.HeaderSignature, "bad")
			},
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			auth := NewInternalAuth("primary", "shared-secret", time.Minute)
			body := []byte(`{"battle_id":"battle_a"}`)
			req := httptest.NewRequest(http.MethodPost, "/internal/v1/battles/allocate", bytes.NewReader(body))
			signRequest(t, req, body, "primary", "shared-secret", time.Now().UTC())
			tc.mutateFunc(req)
			if err := auth.ValidateRequest(req); err == nil {
				t.Fatal("expected internal auth validation failure")
			}
		})
	}
}

func TestInternalAuthRejectsNonceReplay(t *testing.T) {
	auth := NewInternalAuth("primary", "shared-secret", time.Minute)
	body := []byte(`{"battle_id":"battle_a"}`)
	req := httptest.NewRequest(http.MethodPost, "/internal/v1/battles/allocate", bytes.NewReader(body))
	signRequest(t, req, body, "primary", "shared-secret", time.Now().UTC())

	if err := auth.ValidateRequest(req); err != nil {
		t.Fatalf("first request should pass: %v", err)
	}

	reqReplay := httptest.NewRequest(http.MethodPost, "/internal/v1/battles/allocate", bytes.NewReader(body))
	for _, key := range []string{
		internalhttp.HeaderKeyID,
		internalhttp.HeaderTimestamp,
		internalhttp.HeaderNonce,
		internalhttp.HeaderBodySHA256,
		internalhttp.HeaderSignature,
	} {
		reqReplay.Header.Set(key, req.Header.Get(key))
	}
	if err := auth.ValidateRequest(reqReplay); err == nil {
		t.Fatal("expected replayed nonce to be rejected")
	}
}

func signRequest(t *testing.T, req *http.Request, body []byte, keyID string, secret string, now time.Time) {
	t.Helper()
	timestamp := strconv.FormatInt(now.UTC().Unix(), 10)
	nonce := "nonce-" + timestamp
	bodyHash := internalhttp.BodySHA256Hex(body)
	signature := internalhttp.Sign(req.Method, req.URL.RequestURI(), timestamp, nonce, bodyHash, secret)

	req.Header.Set(internalhttp.HeaderKeyID, keyID)
	req.Header.Set(internalhttp.HeaderTimestamp, timestamp)
	req.Header.Set(internalhttp.HeaderNonce, nonce)
	req.Header.Set(internalhttp.HeaderBodySHA256, bodyHash)
	req.Header.Set(internalhttp.HeaderSignature, signature)
}
