package storage

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type WalletBalance struct {
	ProfileID  string
	CurrencyID string
	Balance    int64
	Revision   int64
	UpdatedAt  time.Time
}

type WalletLedgerEntry struct {
	LedgerID       string
	ProfileID      string
	CurrencyID     string
	Delta          int64
	BalanceAfter   int64
	Reason         string
	RefType        string
	RefID          string
	IdempotencyKey string
	CreatedAt      time.Time
}

type WalletRepository struct {
	db DBTX
}

func NewWalletRepository(db DBTX) *WalletRepository {
	return &WalletRepository{db: db}
}

func (r *WalletRepository) ListBalances(ctx context.Context, profileID string) ([]WalletBalance, error) {
	rows, err := r.db.Query(
		ctx,
		`SELECT
			profile_id,
			currency_id,
			balance,
			revision,
			updated_at
		FROM wallet_balances
		WHERE profile_id = $1
		ORDER BY currency_id`,
		profileID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	balances := make([]WalletBalance, 0)
	for rows.Next() {
		var balance WalletBalance
		if err := rows.Scan(
			&balance.ProfileID,
			&balance.CurrencyID,
			&balance.Balance,
			&balance.Revision,
			&balance.UpdatedAt,
		); err != nil {
			return nil, err
		}
		balances = append(balances, balance)
	}
	return balances, rows.Err()
}

func (r *WalletRepository) CreditBalance(ctx context.Context, profileID string, currencyID string, amount int64, updatedAt time.Time) (WalletBalance, error) {
	row := r.db.QueryRow(
		ctx,
		`INSERT INTO wallet_balances (
			profile_id,
			currency_id,
			balance,
			revision,
			updated_at
		) VALUES ($1, $2, $3, 1, $4)
		ON CONFLICT (profile_id, currency_id)
		DO UPDATE SET
			balance = wallet_balances.balance + EXCLUDED.balance,
			revision = wallet_balances.revision + 1,
			updated_at = EXCLUDED.updated_at
		RETURNING profile_id, currency_id, balance, revision, updated_at`,
		profileID,
		currencyID,
		amount,
		updatedAt,
	)
	return scanWalletBalance(row)
}

func (r *WalletRepository) DebitBalance(ctx context.Context, profileID string, currencyID string, amount int64, updatedAt time.Time) (WalletBalance, error) {
	row := r.db.QueryRow(
		ctx,
		`UPDATE wallet_balances
		SET balance = balance - $3,
			revision = revision + 1,
			updated_at = $4
		WHERE profile_id = $1
			AND currency_id = $2
			AND balance >= $3
		RETURNING profile_id, currency_id, balance, revision, updated_at`,
		profileID,
		currencyID,
		amount,
		updatedAt,
	)
	return scanWalletBalance(row)
}

func (r *WalletRepository) InsertLedgerEntry(ctx context.Context, entry WalletLedgerEntry) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO wallet_ledger_entries (
			ledger_id,
			profile_id,
			currency_id,
			delta,
			balance_after,
			reason,
			ref_type,
			ref_id,
			idempotency_key,
			created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		entry.LedgerID,
		entry.ProfileID,
		entry.CurrencyID,
		entry.Delta,
		entry.BalanceAfter,
		entry.Reason,
		entry.RefType,
		entry.RefID,
		nullStringFromPlain(entry.IdempotencyKey),
		entry.CreatedAt,
	)
	return err
}

func (r *WalletRepository) BumpProfileWalletRevision(ctx context.Context, profileID string) (int64, error) {
	var revision int64
	err := r.db.QueryRow(
		ctx,
		`UPDATE player_profiles
		SET wallet_revision = wallet_revision + 1,
			updated_at = NOW()
		WHERE profile_id = $1
		RETURNING wallet_revision`,
		profileID,
	).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return revision, err
}

func scanWalletBalance(scanner interface{ Scan(dest ...any) error }) (WalletBalance, error) {
	var balance WalletBalance
	err := scanner.Scan(
		&balance.ProfileID,
		&balance.CurrencyID,
		&balance.Balance,
		&balance.Revision,
		&balance.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return WalletBalance{}, ErrNotFound
	}
	return balance, err
}

func nullStringFromPlain(value string) any {
	if value == "" {
		return nil
	}
	return value
}
