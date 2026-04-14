package httpapi

import (
	"net/http"

	"qqtang/services/game_service/internal/career"
	"qqtang/services/game_service/internal/platform/httpx"
)

type CareerHandler struct {
	service *career.Service
}

func NewCareerHandler(service *career.Service) *CareerHandler {
	return &CareerHandler{service: service}
}

func (h *CareerHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	claims := getAuthClaims(r.Context())
	summary, err := h.service.GetSummary(r.Context(), claims.AccountID, claims.ProfileID)
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                     true,
		"profile_id":             summary.ProfileID,
		"account_id":             summary.AccountID,
		"summary_state":          summary.SummaryState,
		"current_season_id":      summary.CurrentSeasonID,
		"current_rating":         summary.CurrentRating,
		"current_rank_tier":      summary.CurrentRankTier,
		"career_total_matches":   summary.CareerTotalMatches,
		"career_total_wins":      summary.CareerTotalWins,
		"career_total_losses":    summary.CareerTotalLosses,
		"career_total_draws":     summary.CareerTotalDraws,
		"career_win_rate_bp":     summary.CareerWinRateBP,
		"last_match_id":          summary.LastMatchID,
		"last_match_outcome":     summary.LastMatchOutcome,
		"last_match_finished_at": summary.LastMatchFinishedAt,
		"season_matches_played":  summary.SeasonMatchesPlayed,
		"season_wins":            summary.SeasonWins,
		"season_losses":          summary.SeasonLosses,
		"season_draws":           summary.SeasonDraws,
		"updated_at":             summary.UpdatedAt,
	})
}
