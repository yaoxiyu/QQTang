package httpapi

import (
	"log"
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
	"qqtang/services/ds_manager_service/internal/process"
)

type AllocateHandler struct {
	alloc   *allocator.Allocator
	runner  *process.GodotProcessRunner
}

func NewAllocateHandler(alloc *allocator.Allocator, runner *process.GodotProcessRunner) *AllocateHandler {
	return &AllocateHandler{alloc: alloc, runner: runner}
}

func (h *AllocateHandler) Handle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		BattleID            string `json:"battle_id"`
		AssignmentID        string `json:"assignment_id"`
		MatchID             string `json:"match_id"`
		HostHint            string `json:"host_hint"`
		ExpectedMemberCount int    `json:"expected_member_count"`
	}

	if err := httpx.DecodeJSONBody(w, r, &req); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}

	if req.BattleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	result, err := h.alloc.Allocate(allocator.AllocateRequest{
		BattleID:            req.BattleID,
		AssignmentID:        req.AssignmentID,
		MatchID:             req.MatchID,
		HostHint:            req.HostHint,
		ExpectedMemberCount: req.ExpectedMemberCount,
	})
	if err != nil {
		httpx.WriteError(w, http.StatusConflict, "ALLOCATION_FAILED", err.Error())
		return
	}

	pid, err := h.runner.StartWithCallback(
		req.BattleID, req.AssignmentID, req.MatchID,
		result.Host, result.Port,
		func(battleID string, exitErr error) {
			if exitErr != nil {
				log.Printf("[ds_manager] battle DS crashed battle_id=%s err=%v", battleID, exitErr)
				h.alloc.MarkFailed(battleID)
			} else {
				h.alloc.MarkFinished(battleID)
			}
		},
	)
	if err != nil {
		h.alloc.Release(req.BattleID)
		httpx.WriteError(w, http.StatusInternalServerError, "PROCESS_START_FAILED", err.Error())
		return
	}

	h.alloc.SetPID(req.BattleID, pid)

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"ds_instance_id":   result.InstanceID,
		"allocation_state": string(result.State),
		"server_host":      result.Host,
		"server_port":      result.Port,
	})
}
