package auth

import (
	"crypto/sha256"
	"encoding/hex"
)

type PasswordHasher struct{}

func NewPasswordHasher() *PasswordHasher {
	return &PasswordHasher{}
}

func (h *PasswordHasher) Hash(password string) (string, string) {
	sum := sha256.Sum256([]byte(password))
	return hex.EncodeToString(sum[:]), "sha256"
}

func (h *PasswordHasher) Verify(password string, passwordHash string) bool {
	hashed, _ := h.Hash(password)
	return hashed == passwordHash
}
