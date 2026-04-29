package httpapi

import (
	"log"
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
	"qqtang/services/ds_manager_service/internal/process"
	"qqtang/services/ds_manager_service/internal/runtimepool"
)

type AllocateHandler struct {
	alloc  *allocator.Allocator
	runner *process.GodotProcessRunner
	pool   runtimepool.RuntimePool
}

func NewAllocateHandler(alloc *allocator.Allocator, runner *process.GodotProcessRunner) *AllocateHandler {
	return &AllocateHandler{alloc: alloc, runner: runner}
}

func NewRuntimePoolAllocateHandler(pool runtimepool.RuntimePool) *AllocateHandler {
	return &AllocateHandler{pool: pool}
}

func (h *AllocateHandler) Handle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		BattleID            string `json:"battle_id"`
		AssignmentID        string `json:"assignment_id"`
		MatchID             string `json:"match_id"`
		SourceRoomID        string `json:"source_room_id"`
		HostHint            string `json:"host_hint"`
		ExpectedMemberCount int    `json:"expected_member_count"`
		WaitReady           bool   `json:"wait_ready"`
		IdempotencyKey      string `json:"idempotency_key"`
		LeaseTTLSec         int    `json:"lease_ttl_sec"`
	}

	if err := httpx.DecodeJSONBody(w, r, &req); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}

	if req.BattleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if h.pool != nil {
		result, err := h.pool.Allocate(r.Context(), runtimepool.AllocationSpec{
			BattleID:            req.BattleID,
			AssignmentID:        req.AssignmentID,
			MatchID:             req.MatchID,
			SourceRoomID:        req.SourceRoomID,
			ExpectedMemberCount: req.ExpectedMemberCount,
			HostHint:            req.HostHint,
			WaitReady:           req.WaitReady,
			IdempotencyKey:      req.IdempotencyKey,
			LeaseTTLSec:         req.LeaseTTLSec,
		})
		if err != nil {
			httpx.WriteError(w, http.StatusInternalServerError, "ALLOCATION_FAILED", err.Error())
			return
		}
		if !result.OK {
			httpx.WriteJSON(w, http.StatusConflict, result)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, result)
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
