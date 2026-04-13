package httpapi

import (
	"net/http"
	"strings"

	"qqtang/services/game_service/internal/finalize"
)

type SettlementHandler struct {
	service *finalize.Service
}

func NewSettlementHandler(service *finalize.Service) *SettlementHandler {
	return &SettlementHandler{service: service}
}

func (h *SettlementHandler) GetMatchSummary(w http.ResponseWriter, r *http.Request) {
	matchID := strings.TrimPrefix(r.URL.Path, "/api/v1/settlement/matches/")
	claims := getAuthClaims(r.Context())
	summary, err := h.service.GetMatchSummary(r.Context(), matchID, claims.AccountID, claims.ProfileID)
	if err != nil {
		code, message := mapError(err)
		writeError(w, code, message, message)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                 true,
		"match_id":           summary.MatchID,
		"profile_id":         summary.ProfileID,
		"server_sync_state":  summary.ServerSyncState,
		"outcome":            summary.Outcome,
		"rating_before":      summary.RatingBefore,
		"rating_delta":       summary.RatingDelta,
		"rating_after":       summary.RatingAfter,
		"rank_tier_after":    summary.RankTierAfter,
		"season_point_delta": summary.SeasonPointDelta,
		"career_xp_delta":    summary.CareerXPDelta,
		"gold_delta":         summary.GoldDelta,
		"reward_summary":     summary.RewardSummary,
		"career_summary":     summary.CareerSummary,
		"updated_at":         summary.UpdatedAt,
	})
}
