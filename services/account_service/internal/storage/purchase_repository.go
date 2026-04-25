package storage

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type PurchaseOrder struct {
	PurchaseID      string
	ProfileID       string
	OfferID         string
	CatalogRevision int64
	CurrencyID      string
	Price           int64
	Status          string
	IdempotencyKey  string
	RequestJSON     json.RawMessage
	ResultJSON      json.RawMessage
	CreatedAt       time.Time
	CompletedAt     sql.NullTime
}

type PurchaseGrant struct {
	GrantID    string
	PurchaseID string
	ProfileID  string
	AssetType  string
	AssetID    string
	Quantity   int64
	GrantedAt  time.Time
}

type PurchaseRepository struct {
	db DBTX
}

func NewPurchaseRepository(db DBTX) *PurchaseRepository {
	return &PurchaseRepository{db: db}
}

func (r *PurchaseRepository) FindOrderByIdempotencyKey(ctx context.Context, profileID string, idempotencyKey string) (PurchaseOrder, error) {
	row := r.db.QueryRow(
		ctx,
		`SELECT
			purchase_id,
			profile_id,
			offer_id,
			catalog_revision,
			currency_id,
			price,
			status,
			idempotency_key,
			request_json,
			result_json,
			created_at,
			completed_at
		FROM purchase_orders
		WHERE profile_id = $1
			AND idempotency_key = $2`,
		profileID,
		idempotencyKey,
	)
	return scanPurchaseOrder(row)
}

func (r *PurchaseRepository) InsertOrder(ctx context.Context, order PurchaseOrder) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO purchase_orders (
			purchase_id,
			profile_id,
			offer_id,
			catalog_revision,
			currency_id,
			price,
			status,
			idempotency_key,
			request_json,
			result_json,
			created_at,
			completed_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		order.PurchaseID,
		order.ProfileID,
		order.OfferID,
		order.CatalogRevision,
		order.CurrencyID,
		order.Price,
		order.Status,
		order.IdempotencyKey,
		[]byte(order.RequestJSON),
		[]byte(order.ResultJSON),
		order.CreatedAt,
		order.CompletedAt,
	)
	return err
}

func (r *PurchaseRepository) CompleteOrder(ctx context.Context, purchaseID string, resultJSON json.RawMessage, completedAt time.Time) error {
	_, err := r.db.Exec(
		ctx,
		`UPDATE purchase_orders
		SET status = 'completed',
			result_json = $2,
			completed_at = $3
		WHERE purchase_id = $1`,
		purchaseID,
		[]byte(resultJSON),
		completedAt,
	)
	return err
}

func (r *PurchaseRepository) InsertGrant(ctx context.Context, grant PurchaseGrant) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO purchase_grants (
			grant_id,
			purchase_id,
			profile_id,
			asset_type,
			asset_id,
			quantity,
			granted_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		grant.GrantID,
		grant.PurchaseID,
		grant.ProfileID,
		grant.AssetType,
		grant.AssetID,
		grant.Quantity,
		grant.GrantedAt,
	)
	return err
}

func scanPurchaseOrder(scanner interface{ Scan(dest ...any) error }) (PurchaseOrder, error) {
	var order PurchaseOrder
	err := scanner.Scan(
		&order.PurchaseID,
		&order.ProfileID,
		&order.OfferID,
		&order.CatalogRevision,
		&order.CurrencyID,
		&order.Price,
		&order.Status,
		&order.IdempotencyKey,
		&order.RequestJSON,
		&order.ResultJSON,
		&order.CreatedAt,
		&order.CompletedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return PurchaseOrder{}, ErrNotFound
	}
	return order, err
}
