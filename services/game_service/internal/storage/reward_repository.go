package storage

import (
	"context"
	"time"
)

type RewardLedgerEntry struct {
	LedgerID   string
	AccountID  string
	ProfileID  string
	MatchID    string
	RewardType string
	Delta      int
	SourceType string
	ExtraJSON  string
	IssuedAt   time.Time
}

type RewardRepository struct {
	db DBTX
}

func NewRewardRepository(db DBTX) *RewardRepository {
	return &RewardRepository{db: db}
}

func (r *RewardRepository) Insert(ctx context.Context, entry RewardLedgerEntry) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO reward_ledger_entries (
			ledger_id, account_id, profile_id, match_id, reward_type, delta, source_type, extra_json, issued_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9
		)
	`, entry.LedgerID, entry.AccountID, entry.ProfileID, entry.MatchID, entry.RewardType, entry.Delta, entry.SourceType, entry.ExtraJSON, entry.IssuedAt)
	return err
}
