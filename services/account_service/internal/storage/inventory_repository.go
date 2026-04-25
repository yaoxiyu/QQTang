package storage

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type InventoryRepository struct {
	db DBTX
}

func NewInventoryRepository(db DBTX) *InventoryRepository {
	return &InventoryRepository{db: db}
}

func (r *InventoryRepository) ListAssets(ctx context.Context, profileID string) ([]OwnedAsset, error) {
	rows, err := r.db.Query(
		ctx,
		`SELECT
			account_id,
			profile_id,
			asset_type,
			asset_id,
			state,
			quantity,
			acquired_at,
			expire_at,
			source_type,
			source_ref_id,
			revision
		FROM player_owned_assets
		WHERE profile_id = $1
		ORDER BY asset_type, asset_id`,
		profileID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	assets := make([]OwnedAsset, 0)
	for rows.Next() {
		asset, err := scanOwnedAsset(rows)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}
	return assets, rows.Err()
}

func (r *InventoryRepository) GrantAsset(ctx context.Context, asset OwnedAsset) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO player_owned_assets (
			account_id,
			profile_id,
			asset_type,
			asset_id,
			state,
			quantity,
			acquired_at,
			expire_at,
			source_type,
			source_ref_id,
			revision
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1)
		ON CONFLICT (profile_id, asset_type, asset_id)
		DO UPDATE SET
			state = EXCLUDED.state,
			quantity = player_owned_assets.quantity + EXCLUDED.quantity,
			expire_at = EXCLUDED.expire_at,
			source_type = EXCLUDED.source_type,
			source_ref_id = EXCLUDED.source_ref_id,
			revision = player_owned_assets.revision + 1`,
		asset.AccountID,
		asset.ProfileID,
		asset.AssetType,
		asset.AssetID,
		defaultAssetState(asset.State),
		defaultInt64(asset.Quantity, 1),
		asset.AcquiredAt,
		nullTimeValue(asset.ExpireAt),
		asset.SourceType,
		nullStringValue(asset.SourceRefID),
	)
	return err
}

func (r *InventoryRepository) HasUsableAsset(ctx context.Context, profileID string, assetType string, assetID string, now time.Time) (bool, error) {
	var found int
	err := r.db.QueryRow(
		ctx,
		`SELECT 1
		FROM player_owned_assets
		WHERE profile_id = $1
			AND asset_type = $2
			AND asset_id = $3
			AND state = 'owned'
			AND (expire_at IS NULL OR expire_at > $4)
		LIMIT 1`,
		profileID,
		assetType,
		assetID,
		now,
	).Scan(&found)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func (r *InventoryRepository) BumpProfileOwnedAssetRevision(ctx context.Context, profileID string) (int64, error) {
	var revision int64
	err := r.db.QueryRow(
		ctx,
		`UPDATE player_profiles
		SET owned_asset_revision = owned_asset_revision + 1,
			updated_at = NOW()
		WHERE profile_id = $1
		RETURNING owned_asset_revision`,
		profileID,
	).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return revision, err
}

func scanOwnedAsset(scanner interface{ Scan(dest ...any) error }) (OwnedAsset, error) {
	var asset OwnedAsset
	err := scanner.Scan(
		&asset.AccountID,
		&asset.ProfileID,
		&asset.AssetType,
		&asset.AssetID,
		&asset.State,
		&asset.Quantity,
		&asset.AcquiredAt,
		&asset.ExpireAt,
		&asset.SourceType,
		&asset.SourceRefID,
		&asset.Revision,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return OwnedAsset{}, ErrNotFound
	}
	return asset, err
}

func defaultAssetState(value string) string {
	if value == "" {
		return "owned"
	}
	return value
}

func nullStringFromSQL(value sql.NullString) string {
	if !value.Valid {
		return ""
	}
	return value.String
}

func nullTimeFromSQL(value sql.NullTime) *time.Time {
	if !value.Valid {
		return nil
	}
	v := value.Time
	return &v
}
