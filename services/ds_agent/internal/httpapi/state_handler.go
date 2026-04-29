package httpapi

import (
	"net/http"

	"qqtang/services/ds_agent/internal/platform/httpx"
	"qqtang/services/ds_agent/internal/state"
)

type StateHandler struct {
	store *state.Store
}

func NewStateHandler(store *state.Store) *StateHandler {
	return &StateHandler{store: store}
}

func (h *StateHandler) Handle(w http.ResponseWriter, r *http.Request) {
	snapshot := h.store.Snapshot()
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":            true,
		"state":         snapshot.State,
		"lease_id":      snapshot.LeaseID,
		"battle_id":     snapshot.BattleID,
		"assignment_id": snapshot.AssignmentID,
		"match_id":      snapshot.MatchID,
		"battle_port":   snapshot.BattlePort,
		"pid":           snapshot.PID,
		"started_at":    snapshot.StartedAt,
	})
}
