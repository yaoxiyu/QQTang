package auth

import (
	"errors"
	"net/http"
)

var ErrInternalAuthInvalid = errors.New("INTERNAL_AUTH_INVALID")

type InternalAuth struct {
	sharedSecret string
}

func NewInternalAuth(sharedSecret string) *InternalAuth {
	return &InternalAuth{sharedSecret: sharedSecret}
}

func (a *InternalAuth) ValidateRequest(r *http.Request) error {
	if r == nil {
		return ErrInternalAuthInvalid
	}
	if r.Header.Get("X-Internal-Secret") != a.sharedSecret {
		return ErrInternalAuthInvalid
	}
	return nil
}
