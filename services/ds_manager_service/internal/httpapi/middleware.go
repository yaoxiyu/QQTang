package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/shared/httpx"
)

func withInternalAuth(internalAuth *auth.InternalAuth, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if internalAuth == nil || internalAuth.ValidateRequest(r) != nil {
			httpx.WriteError(w, http.StatusUnauthorized, "INTERNAL_AUTH_INVALID", "Internal auth failed")
			return
		}
		next.ServeHTTP(w, r)
	})
}
