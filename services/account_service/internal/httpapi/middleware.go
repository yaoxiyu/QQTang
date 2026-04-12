package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"qqtang/services/account_service/internal/auth"
)

type contextKey string

const authContextKey contextKey = "auth_result"

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code string, message string) {
	writeJSON(w, status, map[string]any{
		"ok":         false,
		"error_code": code,
		"message":    message,
	})
}

func withAuth(authService *auth.AuthService, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "AUTH_ACCESS_TOKEN_INVALID", "Missing access token")
			return
		}
		result, err := authService.ValidateAccessToken(r.Context(), strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			status, code := mapError(err)
			writeError(w, status, code, code)
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
	case auth.ErrAccountDisabled, auth.ErrAccountBanned:
		return http.StatusForbidden, err.Error()
	case auth.ErrDeviceSessionMismatch:
		return http.StatusConflict, err.Error()
	default:
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
