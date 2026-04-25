package storage

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Profile struct {
	ProfileID              string
	AccountID              string
	Nickname               string
	AvatarID               sql.NullString
	TitleID                sql.NullString
	DefaultCharacterID     string
	DefaultCharacterSkinID string
	DefaultBubbleStyleID   string
	DefaultBubbleSkinID    string
	PreferredModeID        sql.NullString
	PreferredMapID         sql.NullString
	PreferredRuleSetID     sql.NullString
	ProfileVersion         int64
	OwnedAssetRevision     int64
	WalletRevision         int64
	UpdatedAt              time.Time
}

type OwnedAsset struct {
	AccountID   string
	ProfileID   string
	AssetType   string
	AssetID     string
	State       string
	Quantity    int64
	AcquiredAt  time.Time
	ExpireAt    sql.NullTime
	SourceType  string
	SourceRefID sql.NullString
	Revision    int64
}

type ProfileRepository struct {
	db DBTX
}

func NewProfileRepository(db DBTX) *ProfileRepository {
	return &ProfileRepository{db: db}
}

func (r *ProfileRepository) Create(ctx context.Context, profile Profile) error {
	_, err := r.db.Exec(
		ctx,
		`INSERT INTO player_profiles (
			profile_id,
			account_id,
			nickname,
			avatar_id,
			title_id,
			default_character_id,
			default_character_skin_id,
			default_bubble_style_id,
			default_bubble_skin_id,
			preferred_mode_id,
			preferred_map_id,
			preferred_rule_set_id,
			profile_version,
			owned_asset_revision,
			wallet_revision,
			updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
		profile.ProfileID,
		profile.AccountID,
		profile.Nickname,
		nullStringValue(profile.AvatarID),
		nullStringValue(profile.TitleID),
		profile.DefaultCharacterID,
		profile.DefaultCharacterSkinID,
		profile.DefaultBubbleStyleID,
		profile.DefaultBubbleSkinID,
		nullStringValue(profile.PreferredModeID),
		nullStringValue(profile.PreferredMapID),
		nullStringValue(profile.PreferredRuleSetID),
		profile.ProfileVersion,
		profile.OwnedAssetRevision,
		profile.WalletRevision,
		profile.UpdatedAt,
	)
	return err
}

func (r *ProfileRepository) FindByAccountID(ctx context.Context, accountID string) (Profile, error) {
	row := r.db.QueryRow(
		ctx,
		`SELECT
			profile_id,
			account_id,
			nickname,
			avatar_id,
			title_id,
			default_character_id,
			default_character_skin_id,
			default_bubble_style_id,
			default_bubble_skin_id,
			preferred_mode_id,
			preferred_map_id,
			preferred_rule_set_id,
			profile_version,
			owned_asset_revision,
			wallet_revision,
			updated_at
		FROM player_profiles
		WHERE account_id = $1`,
		accountID,
	)
	return scanProfile(row)
}

func (r *ProfileRepository) UpdateProfile(ctx context.Context, profile Profile) error {
	_, err := r.db.Exec(
		ctx,
		`UPDATE player_profiles
		SET nickname = $2,
			preferred_mode_id = $3,
			preferred_map_id = $4,
			preferred_rule_set_id = $5,
			profile_version = $6,
			updated_at = $7
		WHERE profile_id = $1`,
		profile.ProfileID,
		profile.Nickname,
		nullStringValue(profile.PreferredModeID),
		nullStringValue(profile.PreferredMapID),
		nullStringValue(profile.PreferredRuleSetID),
		profile.ProfileVersion,
		profile.UpdatedAt,
	)
	return err
}

func (r *ProfileRepository) UpdateLoadout(ctx context.Context, profile Profile) error {
	_, err := r.db.Exec(
		ctx,
		`UPDATE player_profiles
		SET default_character_id = $2,
			default_character_skin_id = $3,
			default_bubble_style_id = $4,
			default_bubble_skin_id = $5,
			avatar_id = $6,
			title_id = $7,
			profile_version = $8,
			updated_at = $9
		WHERE profile_id = $1`,
		profile.ProfileID,
		profile.DefaultCharacterID,
		profile.DefaultCharacterSkinID,
		profile.DefaultBubbleStyleID,
		profile.DefaultBubbleSkinID,
		nullStringValue(profile.AvatarID),
		nullStringValue(profile.TitleID),
		profile.ProfileVersion,
		profile.UpdatedAt,
	)
	return err
}

func (r *ProfileRepository) InsertOwnedAsset(ctx context.Context, asset OwnedAsset) error {
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
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (profile_id, asset_type, asset_id) DO NOTHING`,
		asset.AccountID,
		asset.ProfileID,
		asset.AssetType,
		asset.AssetID,
		asset.State,
		defaultInt64(asset.Quantity, 1),
		asset.AcquiredAt,
		nullTimeValue(asset.ExpireAt),
		asset.SourceType,
		nullStringValue(asset.SourceRefID),
		defaultInt64(asset.Revision, 1),
	)
	return err
}

func (r *ProfileRepository) ListOwnedAssets(ctx context.Context, profileID string) ([]OwnedAsset, error) {
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
			AND state = 'owned'
		ORDER BY asset_type, asset_id`,
		profileID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	assets := make([]OwnedAsset, 0)
	for rows.Next() {
		var asset OwnedAsset
		if err := rows.Scan(
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
		); err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}
	return assets, rows.Err()
}

func scanProfile(scanner interface{ Scan(dest ...any) error }) (Profile, error) {
	var profile Profile
	err := scanner.Scan(
		&profile.ProfileID,
		&profile.AccountID,
		&profile.Nickname,
		&profile.AvatarID,
		&profile.TitleID,
		&profile.DefaultCharacterID,
		&profile.DefaultCharacterSkinID,
		&profile.DefaultBubbleStyleID,
		&profile.DefaultBubbleSkinID,
		&profile.PreferredModeID,
		&profile.PreferredMapID,
		&profile.PreferredRuleSetID,
		&profile.ProfileVersion,
		&profile.OwnedAssetRevision,
		&profile.WalletRevision,
		&profile.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	return profile, err
}

func nullStringValue(value sql.NullString) any {
	if !value.Valid {
		return nil
	}
	return value.String
}

func nullTimeValue(value sql.NullTime) any {
	if !value.Valid {
		return nil
	}
	return value.Time
}

func defaultInt64(value int64, fallback int64) int64 {
	if value == 0 {
		return fallback
	}
	return value
}
