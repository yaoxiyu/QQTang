package httpapi

import (
	"net/http"

	"qqtang/services/shared/httpx"
	"qqtang/services/ds_manager_service/internal/runtimepool"
)

type StatusHandler struct {
	pool runtimepool.RuntimePool
}

func NewStatusHandler(pool runtimepool.RuntimePool) *StatusHandler {
	return &StatusHandler{pool: pool}
}

func (h *StatusHandler) Handle(w http.ResponseWriter, r *http.Request) {
	if h == nil || h.pool == nil {
		httpx.WriteError(w, http.StatusNotFound, "NOT_FOUND", "battle status is not available")
		return
	}
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}
	result, err := h.pool.GetBattle(r.Context(), battleID)
	if err != nil {
		httpx.WriteError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}
