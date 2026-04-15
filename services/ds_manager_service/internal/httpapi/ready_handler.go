package httpapi

import (
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
)

type ReadyHandler struct {
	alloc *allocator.Allocator
}

func NewReadyHandler(alloc *allocator.Allocator) *ReadyHandler {
	return &ReadyHandler{alloc: alloc}
}

func (h *ReadyHandler) Handle(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if err := h.alloc.MarkReady(battleID); err != nil {
		httpx.WriteError(w, http.StatusConflict, "MARK_READY_FAILED", err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"battle_id": battleID,
		"state":     "ready",
	})
}
