package httpapi

import (
	"net/http"

	"qqtang/services/ds_agent/internal/auth"
	"qqtang/services/ds_agent/internal/platform/httpx"
	"qqtang/services/ds_agent/internal/runtime"
	"qqtang/services/ds_agent/internal/state"
)

type RouterDeps struct {
	InternalAuth *auth.InternalAuth
	StateStore   *state.Store
	Runner       runtime.Runner
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	stateHandler := NewStateHandler(deps.StateStore)
	assignHandler := NewAssignHandler(deps.StateStore, deps.Runner)
	resetHandler := NewResetHandler(deps.StateStore, deps.Runner)

	mux.Handle("GET /internal/v1/agent/state", withInternalAuth(deps.InternalAuth, http.HandlerFunc(stateHandler.Handle)))
	mux.Handle("POST /internal/v1/agent/assign", withInternalAuth(deps.InternalAuth, http.HandlerFunc(assignHandler.Handle)))
	mux.Handle("POST /internal/v1/agent/reset", withInternalAuth(deps.InternalAuth, http.HandlerFunc(resetHandler.Handle)))
	return mux
}

func withInternalAuth(internalAuth *auth.InternalAuth, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if internalAuth == nil || internalAuth.ValidateRequest(r) != nil {
			httpx.WriteError(w, http.StatusUnauthorized, "INTERNAL_AUTH_INVALID", "internal auth validation failed")
			return
		}
		next.ServeHTTP(w, r)
	})
}
