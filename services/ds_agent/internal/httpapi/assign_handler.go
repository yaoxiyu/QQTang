package httpapi

import (
	"context"
	"log"
	"net/http"

	"qqtang/services/shared/httpx"
	"qqtang/services/ds_agent/internal/runtime"
	"qqtang/services/ds_agent/internal/state"
)

type AssignHandler struct {
	store  *state.Store
	runner runtime.Runner
}

func NewAssignHandler(store *state.Store, runner runtime.Runner) *AssignHandler {
	return &AssignHandler{store: store, runner: runner}
}

func (h *AssignHandler) Handle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		LeaseID             string `json:"lease_id"`
		BattleID            string `json:"battle_id"`
		AssignmentID        string `json:"assignment_id"`
		MatchID             string `json:"match_id"`
		ExpectedMemberCount int    `json:"expected_member_count"`
		AdvertiseHost       string `json:"advertise_host"`
		AdvertisePort       int    `json:"advertise_port"`
		GameServiceBaseURL  string `json:"game_service_base_url"`
		DSMBaseURL          string `json:"dsm_base_url"`
		ReadyTimeoutMS      int    `json:"ready_timeout_ms"`
	}
	if err := httpx.DecodeJSONBody(w, r, &req); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	var snapshot state.Snapshot
	var err error
	log.Printf("[ds_agent] assign request lease_id=%s battle_id=%s assignment_id=%s match_id=%s expected_members=%d advertise=%s:%d game_service_base_url=%s dsm_base_url=%s",
		req.LeaseID,
		req.BattleID,
		req.AssignmentID,
		req.MatchID,
		req.ExpectedMemberCount,
		req.AdvertiseHost,
		req.AdvertisePort,
		req.GameServiceBaseURL,
		req.DSMBaseURL,
	)
	if h.runner == nil {
		snapshot, err = h.store.AssignMock(req.LeaseID, req.BattleID, req.AssignmentID, req.MatchID)
	} else {
		snapshot, err = h.store.BeginGodotAssign(req.LeaseID, req.BattleID, req.AssignmentID, req.MatchID)
		if err == nil {
			log.Printf("[ds_agent] assign accepted battle_id=%s assignment_id=%s match_id=%s listen_port=%d",
				req.BattleID,
				req.AssignmentID,
				req.MatchID,
				snapshot.BattlePort,
			)
			info, startErr := h.runner.Start(context.Background(), runtime.StartSpec{
				LeaseID:            req.LeaseID,
				BattleID:           req.BattleID,
				AssignmentID:       req.AssignmentID,
				MatchID:            req.MatchID,
				AdvertiseHost:      req.AdvertiseHost,
				AdvertisePort:      req.AdvertisePort,
				ListenPort:         snapshot.BattlePort,
				GameServiceBaseURL: req.GameServiceBaseURL,
				DSMBaseURL:         req.DSMBaseURL,
			})
			if startErr != nil {
				log.Printf("[ds_agent] godot start failed battle_id=%s assignment_id=%s match_id=%s err=%v",
					req.BattleID,
					req.AssignmentID,
					req.MatchID,
					startErr,
				)
				h.store.MarkFailed()
				err = startErr
			} else {
				log.Printf("[ds_agent] godot start returned battle_id=%s assignment_id=%s match_id=%s pid=%d",
					req.BattleID,
					req.AssignmentID,
					req.MatchID,
					info.PID,
				)
				snapshot = h.store.MarkGodotStarted(info.PID)
			}
		}
	}
	if err != nil {
		log.Printf("[ds_agent] assign rejected battle_id=%s assignment_id=%s match_id=%s err=%v",
			req.BattleID,
			req.AssignmentID,
			req.MatchID,
			err,
		)
		httpx.WriteError(w, http.StatusConflict, "AGENT_ASSIGN_REJECTED", err.Error())
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":            true,
		"agent_state":   snapshot.State,
		"battle_port":   snapshot.BattlePort,
		"lease_id":      snapshot.LeaseID,
		"battle_id":     snapshot.BattleID,
		"assignment_id": snapshot.AssignmentID,
		"match_id":      snapshot.MatchID,
		"pid":           snapshot.PID,
	})
}
