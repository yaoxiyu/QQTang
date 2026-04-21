package httpapi

import (
	"net/http"

	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/platform/httpx"
)

type InternalBattleManifestHandler struct {
	service *battlealloc.Service
}

func NewInternalBattleManifestHandler(service *battlealloc.Service) *InternalBattleManifestHandler {
	return &InternalBattleManifestHandler{service: service}
}

func (h *InternalBattleManifestHandler) GetManifest(w http.ResponseWriter, r *http.Request) {
	battleID := r.PathValue("battle_id")
	if battleID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_BATTLE_ID", "battle_id is required")
		return
	}

	manifest, err := h.service.GetManifest(r.Context(), battleID)
	if err != nil {
		code, errCode := mapBattleAllocError(err)
		httpx.WriteError(w, code, errCode, err.Error())
		return
	}

	members := make([]map[string]any, 0, len(manifest.Members))
	for _, m := range manifest.Members {
		members = append(members, map[string]any{
			"account_id":       m.AccountID,
			"profile_id":       m.ProfileID,
			"assigned_team_id": m.AssignedTeamID,
		})
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                    true,
		"assignment_id":         manifest.AssignmentID,
		"battle_id":             manifest.BattleID,
		"match_id":              manifest.MatchID,
		"source_room_id":        manifest.SourceRoomID,
		"source_room_kind":      manifest.SourceRoomKind,
		"season_id":             manifest.SeasonID,
		"map_id":                manifest.MapID,
		"rule_set_id":           manifest.RuleSetID,
		"mode_id":               manifest.ModeID,
		"expected_member_count": manifest.ExpectedMemberCount,
		"members":               members,
	})
}
