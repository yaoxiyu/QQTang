package auth

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

var (
	ErrAccessTokenInvalid = errors.New("AUTH_ACCESS_TOKEN_INVALID")
	ErrAccessTokenExpired = errors.New("AUTH_ACCESS_TOKEN_EXPIRED")
)

type AccessTokenClaims struct {
	SessionID        string `json:"session_id"`
	AccountID        string `json:"account_id"`
	ProfileID        string `json:"profile_id"`
	DeviceSessionID  string `json:"device_session_id"`
	AuthMode         string `json:"auth_mode"`
	DisplayName      string `json:"display_name"`
	ExpiresAtUnixSec int64  `json:"exp"`
}

type JWTAuth struct {
	secret []byte
}

func NewJWTAuth(secret string) *JWTAuth {
	return &JWTAuth{secret: []byte(secret)}
}

func (a *JWTAuth) ValidateAccessToken(_ context.Context, token string) (AccessTokenClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	if !hmac.Equal([]byte(a.sign(parts[0])), []byte(parts[1])) {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}

	var claims AccessTokenClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	if claims.AccountID == "" || claims.ProfileID == "" {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	if time.Now().UTC().Unix() >= claims.ExpiresAtUnixSec {
		return AccessTokenClaims{}, ErrAccessTokenExpired
	}
	return claims, nil
}

func (a *JWTAuth) sign(value string) string {
	mac := hmac.New(sha256.New, a.secret)
	_, _ = mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
