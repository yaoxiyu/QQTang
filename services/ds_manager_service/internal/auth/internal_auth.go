package auth

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"strconv"
	"sync"
	"time"

	"qqtang/services/shared/internalauth"
)

var ErrInternalAuthInvalid = errors.New("INTERNAL_AUTH_INVALID")

const maxInternalAuthBodyBytes = 1 << 20

type InternalAuth struct {
	sharedSecret string
	keyID        string
	maxSkew      time.Duration
	mu           sync.Mutex
	seenNonces   map[string]time.Time
}

func NewInternalAuth(keyID string, sharedSecret string, maxSkew time.Duration) *InternalAuth {
	if maxSkew <= 0 {
		maxSkew = time.Minute
	}
	return &InternalAuth{
		keyID:        keyID,
		sharedSecret: sharedSecret,
		maxSkew:      maxSkew,
		seenNonces:   map[string]time.Time{},
	}
}

func (a *InternalAuth) ValidateRequest(r *http.Request) error {
	if r == nil || a == nil || a.keyID == "" || a.sharedSecret == "" {
		return ErrInternalAuthInvalid
	}
	body, err := readAndRestoreBody(r)
	if err != nil {
		return ErrInternalAuthInvalid
	}
	keyID := r.Header.Get(internalauth.HeaderKeyID)
	timestamp := r.Header.Get(internalauth.HeaderTimestamp)
	nonce := r.Header.Get(internalauth.HeaderNonce)
	bodyHash := r.Header.Get(internalauth.HeaderBodySHA256)
	signature := r.Header.Get(internalauth.HeaderSignature)
	if keyID == "" || timestamp == "" || nonce == "" || bodyHash == "" || signature == "" {
		return ErrInternalAuthInvalid
	}
	if keyID != a.keyID {
		return ErrInternalAuthInvalid
	}
	if bodyHash != internalauth.BodySHA256Hex(body) {
		return ErrInternalAuthInvalid
	}
	requestUnixSec, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return ErrInternalAuthInvalid
	}
	now := time.Now().UTC()
	requestTime := time.Unix(requestUnixSec, 0).UTC()
	if requestTime.Before(now.Add(-a.maxSkew)) || requestTime.After(now.Add(a.maxSkew)) {
		return ErrInternalAuthInvalid
	}
	expectedSignature := internalauth.Sign(r.Method, r.URL.RequestURI(), timestamp, nonce, bodyHash, a.sharedSecret)
	if !internalauth.SignatureEqual(signature, expectedSignature) {
		return ErrInternalAuthInvalid
	}
	if !a.claimNonce(keyID, nonce, now.Add(a.maxSkew)) {
		return ErrInternalAuthInvalid
	}
	return nil
}

func readAndRestoreBody(r *http.Request) ([]byte, error) {
	if r.Body == nil {
		return nil, nil
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxInternalAuthBodyBytes+1))
	_ = r.Body.Close()
	if err != nil {
		return nil, err
	}
	if len(body) > maxInternalAuthBodyBytes {
		return nil, io.ErrUnexpectedEOF
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	return body, nil
}

func (a *InternalAuth) claimNonce(keyID string, nonce string, expiresAt time.Time) bool {
	a.mu.Lock()
	defer a.mu.Unlock()

	now := time.Now().UTC()
	for cacheKey, cachedExpiresAt := range a.seenNonces {
		if cachedExpiresAt.Before(now) {
			delete(a.seenNonces, cacheKey)
		}
	}

	cacheKey := keyID + ":" + nonce
	if _, exists := a.seenNonces[cacheKey]; exists {
		return false
	}
	a.seenNonces[cacheKey] = expiresAt
	return true
}
