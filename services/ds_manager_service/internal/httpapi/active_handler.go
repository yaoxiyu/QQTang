package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
	"qqtang/services/ds_manager_service/internal/runtimepool"
)

type ActiveHandler struct {
	alloc *allocator.Allocator
	pool  runtimepool.RuntimePool
}

func NewActiveHandler(alloc *allocator.Allocator) *ActiveHandler {
	return &ActiveHandler{alloc: alloc}
}

func NewRuntimePoolActiveHandler(pool runtimepool.RuntimePool) *ActiveHandler {
	return &ActiveHandler{pool: pool}
}

func (h *ActiveHandler) Handle(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if h.pool != nil {
		if err := h.pool.MarkActive(r.Context(), battleID); err != nil {
			httpx.WriteError(w, http.StatusConflict, "MARK_ACTIVE_FAILED", err.Error())
			return
		}
	} else if err := h.alloc.MarkActive(battleID); err != nil {
		httpx.WriteError(w, http.StatusConflict, "MARK_ACTIVE_FAILED", err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"battle_id": battleID,
		"state":     "active",
	})
}
