package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/process"
)

type RouterDeps struct {
	Allocator       *allocator.Allocator
	ProcessRunner   *process.GodotProcessRunner
	InternalAuth    *auth.InternalAuth
	AllocateHandler *AllocateHandler
	ReapHandler     *ReapHandler
	ReadyHandler    *ReadyHandler
	ActiveHandler   *ActiveHandler
	StatusHandler   *StatusHandler
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true}`))
	})

	mux.Handle("POST /internal/v1/battles/allocate", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.AllocateHandler.Handle)))
	mux.Handle("POST /internal/v1/battles/{battle_id}/ready", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.ReadyHandler.Handle)))
	mux.Handle("POST /internal/v1/battles/{battle_id}/active", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.ActiveHandler.Handle)))
	mux.Handle("POST /internal/v1/battles/{battle_id}/reap", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.ReapHandler.Handle)))
	if deps.StatusHandler != nil {
		mux.Handle("GET /internal/v1/battles/{battle_id}", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.StatusHandler.Handle)))
	}

	return mux
}
