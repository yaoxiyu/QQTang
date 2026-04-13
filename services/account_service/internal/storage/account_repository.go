package storage

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

var ErrNotFound = errors.New("not found")

type Account struct {
	AccountID    string
	LoginName    string
	PasswordHash string
	PasswordAlgo string
	Status       string
	CreatedAt    time.Time
	UpdatedAt    time.Time
	LastLoginAt  sql.NullTime
}

type AccountRepository struct {
	db DBTX
}

func NewAccountRepository(db DBTX) *AccountRepository {
	return &AccountRepository{db: db}
}

func (r *AccountRepository) Create(ctx context.Context, account Account) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO accounts (
			account_id,
			login_name,
			password_hash,
			password_algo,
			status,
			created_at,
			updated_at,
			last_login_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		account.AccountID,
		account.LoginName,
		account.PasswordHash,
		account.PasswordAlgo,
		account.Status,
		account.CreatedAt,
		account.UpdatedAt,
		account.LastLoginAt,
	)
	return err
}

func (r *AccountRepository) FindByLoginName(ctx context.Context, loginName string) (Account, error) {
	row := r.db.QueryRow(
		ctx,
		`SELECT
			account_id,
			login_name,
			password_hash,
			password_algo,
			status,
			created_at,
			updated_at,
			last_login_at
		FROM accounts
		WHERE login_name = $1`,
		loginName,
	)
	return scanAccount(row)
}

func (r *AccountRepository) FindByAccountID(ctx context.Context, accountID string) (Account, error) {
	row := r.db.QueryRow(
		ctx,
		`SELECT
			account_id,
			login_name,
			password_hash,
			password_algo,
			status,
			created_at,
			updated_at,
			last_login_at
		FROM accounts
		WHERE account_id = $1`,
		accountID,
	)
	return scanAccount(row)
}

func (r *AccountRepository) UpdateLastLoginAt(ctx context.Context, accountID string, ts time.Time) error {
	_, err := r.db.Exec(
		ctx,
		`UPDATE accounts
		SET last_login_at = $2,
			updated_at = $2
		WHERE account_id = $1`,
		accountID,
		ts,
	)
	return err
}

func scanAccount(scanner interface{ Scan(dest ...any) error }) (Account, error) {
	var account Account
	err := scanner.Scan(
		&account.AccountID,
		&account.LoginName,
		&account.PasswordHash,
		&account.PasswordAlgo,
		&account.Status,
		&account.CreatedAt,
		&account.UpdatedAt,
		&account.LastLoginAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Account{}, ErrNotFound
	}
	return account, err
}
