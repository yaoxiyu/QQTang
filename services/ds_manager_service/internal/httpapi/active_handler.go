package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
)

type ActiveHandler struct {
	alloc *allocator.Allocator
}

func NewActiveHandler(alloc *allocator.Allocator) *ActiveHandler {
	return &ActiveHandler{alloc: alloc}
}

func (h *ActiveHandler) Handle(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if err := h.alloc.MarkActive(battleID); err != nil {
		httpx.WriteError(w, http.StatusConflict, "MARK_ACTIVE_FAILED", err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"battle_id": battleID,
		"state":     "active",
	})
}
