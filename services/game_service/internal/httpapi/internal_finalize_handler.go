package httpapi

import (
	"encoding/json"
	"net/http"

	"qqtang/services/game_service/internal/finalize"
)

type InternalFinalizeHandler struct {
	service *finalize.Service
}

func NewInternalFinalizeHandler(service *finalize.Service) *InternalFinalizeHandler {
	return &InternalFinalizeHandler{service: service}
}

func (h *InternalFinalizeHandler) Finalize(w http.ResponseWriter, r *http.Request) {
	var input finalize.FinalizeInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, "REQUEST_INVALID_JSON", "Invalid JSON")
		return
	}
	result, err := h.service.Finalize(r.Context(), input)
	if err != nil {
		code, message := mapError(err)
		writeError(w, code, message, message)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                 true,
		"finalize_state":     result.FinalizeState,
		"match_id":           result.MatchID,
		"assignment_id":      result.AssignmentID,
		"already_committed":  result.AlreadyCommitted,
		"result_hash":        result.ResultHash,
		"settlement_summary": result.SettlementSummary,
		"finalized_at":       result.FinalizedAt,
	})
}
