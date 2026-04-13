package storage

import "context"

type SeasonRatingSnapshot struct {
	SeasonID      string
	AccountID     string
	ProfileID     string
	Rating        int
	RankTier      string
	MatchesPlayed int
	Wins          int
	Losses        int
	Draws         int
	LastMatchID   string
}

type RatingRepository struct {
	db DBTX
}

func NewRatingRepository(db DBTX) *RatingRepository {
	return &RatingRepository{db: db}
}

func (r *RatingRepository) FindSnapshot(ctx context.Context, seasonID string, accountID string) (SeasonRatingSnapshot, error) {
	var snap SeasonRatingSnapshot
	err := r.db.QueryRow(ctx, `
		SELECT season_id, account_id, profile_id, rating, rank_tier, matches_played, wins, losses, draws, last_match_id
		FROM season_rating_snapshots
		WHERE season_id = $1 AND account_id = $2
	`, seasonID, accountID).Scan(
		&snap.SeasonID, &snap.AccountID, &snap.ProfileID, &snap.Rating, &snap.RankTier, &snap.MatchesPlayed,
		&snap.Wins, &snap.Losses, &snap.Draws, &snap.LastMatchID,
	)
	if err != nil {
		return SeasonRatingSnapshot{}, mapNotFound(err)
	}
	return snap, nil
}

func (r *RatingRepository) UpsertSnapshot(ctx context.Context, snap SeasonRatingSnapshot) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO season_rating_snapshots (
			season_id, account_id, profile_id, rating, rank_tier, matches_played, wins, losses, draws, last_match_id, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW()
		)
		ON CONFLICT (season_id, account_id)
		DO UPDATE SET
			profile_id = EXCLUDED.profile_id,
			rating = EXCLUDED.rating,
			rank_tier = EXCLUDED.rank_tier,
			matches_played = EXCLUDED.matches_played,
			wins = EXCLUDED.wins,
			losses = EXCLUDED.losses,
			draws = EXCLUDED.draws,
			last_match_id = EXCLUDED.last_match_id,
			updated_at = NOW()
	`, snap.SeasonID, snap.AccountID, snap.ProfileID, snap.Rating, snap.RankTier, snap.MatchesPlayed,
		snap.Wins, snap.Losses, snap.Draws, snap.LastMatchID)
	return err
}
