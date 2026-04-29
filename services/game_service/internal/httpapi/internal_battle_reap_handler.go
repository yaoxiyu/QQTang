package httpapi

import (
	"errors"
	"net/http"

	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/platform/httpx"
)

type InternalBattleReapHandler struct {
	service *battlealloc.Service
}

func NewInternalBattleReapHandler(service *battlealloc.Service) *InternalBattleReapHandler {
	return &InternalBattleReapHandler{service: service}
}

func (h *InternalBattleReapHandler) Reap(w http.ResponseWriter, r *http.Request) {
	if h == nil || h.service == nil {
		httpx.WriteError(w, http.StatusServiceUnavailable, "BATTLE_REAP_UNAVAILABLE", "battle reap service is not configured")
		return
	}
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BATTLE_ID_MISSING", "battle_id is required")
		return
	}
	if err := h.service.ReapBattle(r.Context(), battleID); err != nil {
		if errors.Is(err, battlealloc.ErrBattleNotFound) {
			httpx.WriteError(w, http.StatusNotFound, "BATTLE_NOT_FOUND", "battle not found")
			return
		}
		httpx.WriteError(w, http.StatusInternalServerError, "BATTLE_REAP_FAILED", err.Error())
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"battle_id": battleID,
		"reaped":    true,
	})
}
