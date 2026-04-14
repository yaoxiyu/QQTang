package httpapi

import (
	"context"
	"log"
	"net/http"
	"strings"

	"qqtang/services/account_service/internal/auth"
	"qqtang/services/account_service/internal/platform/httpx"
)

type contextKey string

const authContextKey contextKey = "auth_result"

func withAuth(authService *auth.AuthService, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			httpx.WriteError(w, http.StatusUnauthorized, "AUTH_ACCESS_TOKEN_INVALID", "Missing access token")
			return
		}
		result, err := authService.ValidateAccessToken(r.Context(), strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			status, code := mapError(err)
			httpx.WriteError(w, status, code, code)
			return
		}
		ctx := context.WithValue(r.Context(), authContextKey, result)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func getAuthResult(ctx context.Context) auth.AuthResult {
	value, _ := ctx.Value(authContextKey).(auth.AuthResult)
	return value
}

func mapError(err error) (int, string) {
	switch err {
	case auth.ErrAccountAlreadyExists:
		return http.StatusConflict, err.Error()
	case auth.ErrAccountInvalid, auth.ErrPasswordInvalid:
		return http.StatusBadRequest, err.Error()
	case auth.ErrInvalidCredentials, auth.ErrRefreshTokenInvalid, auth.ErrRefreshTokenExpired, auth.ErrSessionRevoked, auth.ErrAccessTokenInvalid, auth.ErrAccessTokenExpired:
		return http.StatusUnauthorized, err.Error()
	case auth.ErrLoginRateLimited:
		return http.StatusTooManyRequests, err.Error()
	case auth.ErrAccountDisabled, auth.ErrAccountBanned, auth.ErrCaptchaRequired, auth.ErrLoginRiskBlocked:
		return http.StatusForbidden, err.Error()
	case auth.ErrDeviceSessionMismatch:
		return http.StatusConflict, err.Error()
	default:
		log.Printf("httpapi internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
