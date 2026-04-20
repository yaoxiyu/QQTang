package httpapi

import (
	"context"
	"net/http"

	"qqtang/services/game_service/internal/finalize"
	"qqtang/services/game_service/internal/platform/httpx"
)

type finalizeExecutor interface {
	Finalize(ctx context.Context, input finalize.FinalizeInput) (finalize.FinalizeResult, error)
}

type InternalFinalizeHandler struct {
	service finalizeExecutor
}

func NewInternalFinalizeHandler(service *finalize.Service) *InternalFinalizeHandler {
	return &InternalFinalizeHandler{service: service}
}

func (h *InternalFinalizeHandler) Finalize(w http.ResponseWriter, r *http.Request) {
	var input finalize.FinalizeInput
	if err := httpx.DecodeJSONBody(w, r, &input); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	result, err := h.service.Finalize(r.Context(), input)
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
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
