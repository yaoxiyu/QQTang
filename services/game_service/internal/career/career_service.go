package career

import (
	"context"
	"errors"
	"time"

	"qqtang/services/game_service/internal/storage"
)

type Service struct {
	careerRepo *storage.CareerRepository
	ratingRepo *storage.RatingRepository
}

type SummaryView struct {
	ProfileID           string     `json:"profile_id"`
	AccountID           string     `json:"account_id"`
	SummaryState        string     `json:"summary_state"`
	CurrentSeasonID     string     `json:"current_season_id"`
	CurrentRating       int        `json:"current_rating"`
	CurrentRankTier     string     `json:"current_rank_tier"`
	CareerTotalMatches  int        `json:"career_total_matches"`
	CareerTotalWins     int        `json:"career_total_wins"`
	CareerTotalLosses   int        `json:"career_total_losses"`
	CareerTotalDraws    int        `json:"career_total_draws"`
	CareerWinRateBP     int        `json:"career_win_rate_bp"`
	LastMatchID         string     `json:"last_match_id"`
	LastMatchOutcome    string     `json:"last_match_outcome"`
	LastMatchFinishedAt *time.Time `json:"last_match_finished_at"`
	SeasonMatchesPlayed int        `json:"season_matches_played"`
	SeasonWins          int        `json:"season_wins"`
	SeasonLosses        int        `json:"season_losses"`
	SeasonDraws         int        `json:"season_draws"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

func NewService(careerRepo *storage.CareerRepository, ratingRepo *storage.RatingRepository) *Service {
	return &Service{careerRepo: careerRepo, ratingRepo: ratingRepo}
}

func (s *Service) GetSummary(ctx context.Context, accountID string, profileID string) (SummaryView, error) {
	summary, err := s.careerRepo.FindByProfileID(ctx, profileID)
	if err != nil {
		if !errors.Is(err, storage.ErrNotFound) {
			return SummaryView{}, err
		}
		now := time.Now().UTC()
		return SummaryView{
			ProfileID:       profileID,
			AccountID:       accountID,
			SummaryState:    "missing",
			CurrentSeasonID: "season_s1",
			CurrentRating:   1000,
			CurrentRankTier: "bronze",
			UpdatedAt:       now,
		}, nil
	}
	snapshot, err := s.ratingRepo.FindSnapshot(ctx, summary.CurrentSeasonID, accountID)
	if err != nil && !errors.Is(err, storage.ErrNotFound) {
		return SummaryView{}, err
	}
	view := SummaryView{
		ProfileID:           summary.ProfileID,
		AccountID:           summary.AccountID,
		SummaryState:        "ready",
		CurrentSeasonID:     summary.CurrentSeasonID,
		CurrentRating:       summary.CurrentRating,
		CurrentRankTier:     summary.CurrentRankTier,
		CareerTotalMatches:  summary.TotalMatches,
		CareerTotalWins:     summary.TotalWins,
		CareerTotalLosses:   summary.TotalLosses,
		CareerTotalDraws:    summary.TotalDraws,
		CareerWinRateBP:     summary.WinRateBP,
		LastMatchID:         summary.LastMatchID,
		LastMatchOutcome:    summary.LastMatchOutcome,
		LastMatchFinishedAt: summary.LastMatchFinishedAt,
		UpdatedAt:           summary.UpdatedAt,
	}
	if err == nil {
		view.SeasonMatchesPlayed = snapshot.MatchesPlayed
		view.SeasonWins = snapshot.Wins
		view.SeasonLosses = snapshot.Losses
		view.SeasonDraws = snapshot.Draws
		view.CurrentRating = snapshot.Rating
		view.CurrentRankTier = snapshot.RankTier
	}
	return view, nil
}
