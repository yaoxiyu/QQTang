package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

type TokenIssuer struct {
	secret []byte
}

type AccessTokenClaims struct {
	AccountID        string `json:"account_id"`
	ProfileID        string `json:"profile_id"`
	DeviceSessionID  string `json:"device_session_id"`
	AuthMode         string `json:"auth_mode"`
	DisplayName      string `json:"display_name"`
	ExpiresAtUnixSec int64  `json:"exp"`
}

func NewTokenIssuer(secret string) *TokenIssuer {
	return &TokenIssuer{secret: []byte(secret)}
}

func (i *TokenIssuer) IssueAccessToken(claims AccessTokenClaims) (string, error) {
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	encoded := base64.RawURLEncoding.EncodeToString(payload)
	return encoded + "." + i.sign(encoded), nil
}

func (i *TokenIssuer) ParseAccessToken(token string) (AccessTokenClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return AccessTokenClaims{}, errors.New("invalid token format")
	}
	if !hmac.Equal([]byte(i.sign(parts[0])), []byte(parts[1])) {
		return AccessTokenClaims{}, errors.New("invalid token signature")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return AccessTokenClaims{}, err
	}
	var claims AccessTokenClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return AccessTokenClaims{}, err
	}
	return claims, nil
}

func (i *TokenIssuer) IssueOpaqueToken(prefix string) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return prefix + "_" + hex.EncodeToString(raw), nil
}

func (i *TokenIssuer) HashOpaqueToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func (i *TokenIssuer) IsExpired(expiresAtUnixSec int64, now time.Time) bool {
	return now.Unix() >= expiresAtUnixSec
}

func (i *TokenIssuer) sign(value string) string {
	mac := hmac.New(sha256.New, i.secret)
	_, _ = mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
