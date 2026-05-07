package httpapi

import (
	"errors"
	"net/http"

	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/shared/httpx"
)

type InternalManualRoomBattleHandler struct {
	service *battlealloc.ManualRoomService
}

func NewInternalManualRoomBattleHandler(service *battlealloc.ManualRoomService) *InternalManualRoomBattleHandler {
	return &InternalManualRoomBattleHandler{service: service}
}

func (h *InternalManualRoomBattleHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req battlealloc.ManualRoomBattleInput

	if err := httpx.DecodeJSONBody(w, r, &req); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}

	if req.SourceRoomID == "" || req.ModeID == "" || len(req.Members) == 0 {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_FIELDS", "source_room_id, mode_id, members are required")
		return
	}

	result, err := h.service.Create(r.Context(), req)
	if err != nil {
		if errors.Is(err, battlealloc.ErrManualRoomInvalidInput) {
			httpx.WriteError(w, http.StatusBadRequest, "MISSING_FIELDS", "source_room_id, mode_id, members are required")
			return
		}
		if errors.Is(err, battlealloc.ErrManualRoomPersistFailed) {
			httpx.WriteError(w, http.StatusInternalServerError, "INSERT_FAILED", err.Error())
			return
		}
		if errors.Is(err, battlealloc.ErrManualRoomAllocationFailed) {
			httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{
				"ok":               false,
				"error_code":       "ALLOCATION_FAILED",
				"message":          err.Error(),
				"assignment_id":    result.AssignmentID,
				"battle_id":        result.BattleID,
				"match_id":         result.MatchID,
				"allocation_state": result.AllocationState,
				"retryable":        true,
			})
			return
		}
		httpx.WriteError(w, http.StatusInternalServerError, "ALLOCATION_FAILED", err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"assignment_id":    result.AssignmentID,
		"battle_id":        result.BattleID,
		"match_id":         result.MatchID,
		"ds_instance_id":   result.DSInstanceID,
		"allocation_state": result.AllocationState,
		"server_host":      result.ServerHost,
		"server_port":      result.ServerPort,
	})
}
