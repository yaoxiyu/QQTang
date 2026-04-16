package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/process"
)

type RouterDeps struct {
	Allocator       *allocator.Allocator
	ProcessRunner   *process.GodotProcessRunner
	AllocateHandler *AllocateHandler
	ReapHandler     *ReapHandler
	ReadyHandler    *ReadyHandler
	ActiveHandler   *ActiveHandler
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true}`))
	})

	mux.HandleFunc("POST /internal/v1/battles/allocate", deps.AllocateHandler.Handle)
	mux.HandleFunc("POST /internal/v1/battles/{battle_id}/ready", deps.ReadyHandler.Handle)
	mux.HandleFunc("POST /internal/v1/battles/{battle_id}/active", deps.ActiveHandler.Handle)
	mux.HandleFunc("POST /internal/v1/battles/{battle_id}/reap", deps.ReapHandler.Handle)

	return mux
}
