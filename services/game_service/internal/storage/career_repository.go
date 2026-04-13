package storage

import (
	"context"
	"time"
)

type CareerSummary struct {
	ProfileID           string
	AccountID           string
	TotalMatches        int
	TotalWins           int
	TotalLosses         int
	TotalDraws          int
	WinRateBP           int
	CurrentSeasonID     string
	CurrentRating       int
	CurrentRankTier     string
	LastMatchID         string
	LastMatchOutcome    string
	LastMatchFinishedAt *time.Time
	UpdatedAt           time.Time
}

type CareerRepository struct {
	db DBTX
}

func NewCareerRepository(db DBTX) *CareerRepository {
	return &CareerRepository{db: db}
}

func (r *CareerRepository) FindByProfileID(ctx context.Context, profileID string) (CareerSummary, error) {
	var summary CareerSummary
	var lastFinishedAt *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT profile_id, account_id, total_matches, total_wins, total_losses, total_draws,
		       win_rate_bp, current_season_id, current_rating, current_rank_tier, last_match_id,
		       last_match_outcome, last_match_finished_at, updated_at
		FROM career_summaries
		WHERE profile_id = $1
	`, profileID).Scan(
		&summary.ProfileID, &summary.AccountID, &summary.TotalMatches, &summary.TotalWins, &summary.TotalLosses,
		&summary.TotalDraws, &summary.WinRateBP, &summary.CurrentSeasonID, &summary.CurrentRating,
		&summary.CurrentRankTier, &summary.LastMatchID, &summary.LastMatchOutcome, &lastFinishedAt, &summary.UpdatedAt,
	)
	if err != nil {
		return CareerSummary{}, mapNotFound(err)
	}
	summary.LastMatchFinishedAt = lastFinishedAt
	return summary, nil
}

func (r *CareerRepository) Upsert(ctx context.Context, summary CareerSummary) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO career_summaries (
			profile_id, account_id, total_matches, total_wins, total_losses, total_draws, win_rate_bp,
			current_season_id, current_rating, current_rank_tier, last_match_id, last_match_outcome,
			last_match_finished_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW()
		)
		ON CONFLICT (profile_id)
		DO UPDATE SET
			account_id = EXCLUDED.account_id,
			total_matches = EXCLUDED.total_matches,
			total_wins = EXCLUDED.total_wins,
			total_losses = EXCLUDED.total_losses,
			total_draws = EXCLUDED.total_draws,
			win_rate_bp = EXCLUDED.win_rate_bp,
			current_season_id = EXCLUDED.current_season_id,
			current_rating = EXCLUDED.current_rating,
			current_rank_tier = EXCLUDED.current_rank_tier,
			last_match_id = EXCLUDED.last_match_id,
			last_match_outcome = EXCLUDED.last_match_outcome,
			last_match_finished_at = EXCLUDED.last_match_finished_at,
			updated_at = NOW()
	`, summary.ProfileID, summary.AccountID, summary.TotalMatches, summary.TotalWins, summary.TotalLosses,
		summary.TotalDraws, summary.WinRateBP, summary.CurrentSeasonID, summary.CurrentRating, summary.CurrentRankTier,
		summary.LastMatchID, summary.LastMatchOutcome, summary.LastMatchFinishedAt)
	return err
}
