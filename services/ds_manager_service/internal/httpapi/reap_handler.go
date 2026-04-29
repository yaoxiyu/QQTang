package httpapi

import (
	"log"
	"net/http"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/platform/httpx"
	"qqtang/services/ds_manager_service/internal/process"
	"qqtang/services/ds_manager_service/internal/runtimepool"
)

type ReapHandler struct {
	alloc  *allocator.Allocator
	runner *process.GodotProcessRunner
	pool   runtimepool.RuntimePool
}

func NewReapHandler(alloc *allocator.Allocator, runner *process.GodotProcessRunner) *ReapHandler {
	return &ReapHandler{alloc: alloc, runner: runner}
}

func NewRuntimePoolReapHandler(pool runtimepool.RuntimePool) *ReapHandler {
	return &ReapHandler{pool: pool}
}

func (h *ReapHandler) Handle(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	if h.pool != nil {
		if err := h.pool.Reap(r.Context(), battleID); err != nil {
			httpx.WriteError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{
			"ok":        true,
			"battle_id": battleID,
			"reaped":    true,
		})
		return
	}

	inst, ok := h.alloc.Get(battleID)
	if !ok {
		httpx.WriteError(w, http.StatusNotFound, "NOT_FOUND", "battle instance not found")
		return
	}

	if h.runner.IsRunning(battleID) {
		if err := h.runner.Kill(battleID); err != nil {
			log.Printf("[ds_manager] failed to kill process battle_id=%s err=%v", battleID, err)
		}
	}

	h.alloc.Release(battleID)

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":             true,
		"battle_id":      battleID,
		"ds_instance_id": inst.InstanceID,
		"reaped":         true,
	})
}
