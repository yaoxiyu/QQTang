package auth

import (
	"crypto/sha256"
	"encoding/hex"

	"golang.org/x/crypto/bcrypt"
)

type PasswordHasher struct{}

func NewPasswordHasher() *PasswordHasher {
	return &PasswordHasher{}
}

func (h *PasswordHasher) HashPassword(plain string) (hash string, algo string, err error) {
	hashed, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	if err != nil {
		return "", "", err
	}
	return string(hashed), "bcrypt", nil
}

func (h *PasswordHasher) VerifyPassword(plain string, hash string, algo string) bool {
	switch algo {
	case "bcrypt":
		return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
	case "sha256":
		sum := sha256.Sum256([]byte(plain))
		return hex.EncodeToString(sum[:]) == hash
	default:
		return false
	}
}
