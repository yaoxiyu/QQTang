package httpapi

import (
	"net/http"

	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/shared/httpx"
)

type InternalBattleReadyHandler struct {
	service *battlealloc.Service
}

func NewInternalBattleReadyHandler(service *battlealloc.Service) *InternalBattleReadyHandler {
	return &InternalBattleReadyHandler{service: service}
}

func (h *InternalBattleReadyHandler) MarkReady(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if err := h.service.MarkBattleReady(r.Context(), battleID); err != nil {
		code, errCode := mapBattleAllocError(err)
		httpx.WriteError(w, code, errCode, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"battle_id": battleID,
		"state":     "battle_ready",
	})
}
