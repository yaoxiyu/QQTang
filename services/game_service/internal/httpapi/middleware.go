package httpapi

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/finalize"
	"qqtang/services/game_service/internal/queue"
)

type contextKey string

const authContextKey contextKey = "auth_claims"

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

func withAuth(jwtAuth *auth.JWTAuth, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "AUTH_ACCESS_TOKEN_INVALID", "Missing access token")
			return
		}
		claims, err := jwtAuth.ValidateAccessToken(r.Context(), strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			status, code := mapError(err)
			writeError(w, status, code, code)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), authContextKey, claims)))
	})
}

func withInternalAuth(internalAuth *auth.InternalAuth, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := internalAuth.ValidateRequest(r); err != nil {
			writeError(w, http.StatusUnauthorized, "INTERNAL_AUTH_INVALID", "Internal auth failed")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func getAuthClaims(ctx context.Context) auth.AccessTokenClaims {
	value, _ := ctx.Value(authContextKey).(auth.AccessTokenClaims)
	return value
}

func mapError(err error) (int, string) {
	switch err {
	case auth.ErrAccessTokenInvalid, auth.ErrAccessTokenExpired:
		return http.StatusUnauthorized, err.Error()
	case auth.ErrInternalAuthInvalid:
		return http.StatusUnauthorized, err.Error()
	case queue.ErrQueueAlreadyActive:
		return http.StatusConflict, err.Error()
	case queue.ErrQueueNotFound:
		return http.StatusNotFound, err.Error()
	case queue.ErrQueueTypeInvalid, queue.ErrModeInvalid, queue.ErrRuleSetInvalid:
		return http.StatusBadRequest, err.Error()
	case queue.ErrAssignmentExpired, queue.ErrAssignmentRevisionStale:
		return http.StatusConflict, err.Error()
	case assignment.ErrAssignmentNotFound, assignment.ErrAssignmentMemberNotFound:
		return http.StatusNotFound, err.Error()
	case assignment.ErrAssignmentExpired, assignment.ErrAssignmentGrantForbidden:
		return http.StatusConflict, err.Error()
	case assignment.ErrAssignmentRevisionStale:
		return http.StatusConflict, err.Error()
	case finalize.ErrFinalizeAlreadyCommitted, finalize.ErrFinalizeHashMismatch:
		return http.StatusConflict, err.Error()
	case finalize.ErrFinalizeAssignmentNotFound, finalize.ErrSettlementMatchNotFound:
		return http.StatusNotFound, err.Error()
	case finalize.ErrFinalizeContextMismatch:
		return http.StatusConflict, err.Error()
	case finalize.ErrFinalizeMemberResultInvalid:
		return http.StatusBadRequest, err.Error()
	default:
		log.Printf("httpapi internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
