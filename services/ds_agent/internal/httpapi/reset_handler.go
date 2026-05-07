package httpapi

import (
	"net/http"

	"qqtang/services/shared/httpx"
	"qqtang/services/ds_agent/internal/runtime"
	"qqtang/services/ds_agent/internal/state"
)

type ResetHandler struct {
	store  *state.Store
	runner runtime.Runner
}

func NewResetHandler(store *state.Store, runner runtime.Runner) *ResetHandler {
	return &ResetHandler{store: store, runner: runner}
}

func (h *ResetHandler) Handle(w http.ResponseWriter, r *http.Request) {
	if h.runner != nil {
		_ = h.runner.Stop()
	}
	snapshot := h.store.Reset()
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":          true,
		"agent_state": snapshot.State,
		"battle_port": snapshot.BattlePort,
		"reset":       true,
	})
}
