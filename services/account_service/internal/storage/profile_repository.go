package storage

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

type Profile struct {
	ProfileID              string
	AccountID              string
	Nickname               string
	DefaultCharacterID     string
	DefaultCharacterSkinID string
	DefaultBubbleStyleID   string
	DefaultBubbleSkinID    string
	PreferredModeID        sql.NullString
	PreferredMapID         sql.NullString
	PreferredRuleSetID     sql.NullString
	ProfileVersion         int64
	OwnedAssetRevision     int64
	UpdatedAt              time.Time
}

type OwnedAsset struct {
	AccountID  string
	ProfileID  string
	AssetType  string
	AssetID    string
	State      string
	AcquiredAt time.Time
	SourceType string
}

type ProfileRepository struct {
	db *sql.DB
}

func NewProfileRepository(db *sql.DB) *ProfileRepository {
	return &ProfileRepository{db: db}
}

func (r *ProfileRepository) Create(ctx context.Context, profile Profile) error {
	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO player_profiles (
			profile_id,
			account_id,
			nickname,
			default_character_id,
			default_character_skin_id,
			default_bubble_style_id,
			default_bubble_skin_id,
			preferred_mode_id,
			preferred_map_id,
			preferred_rule_set_id,
			profile_version,
			owned_asset_revision,
			updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
		profile.ProfileID,
		profile.AccountID,
		profile.Nickname,
		profile.DefaultCharacterID,
		profile.DefaultCharacterSkinID,
		profile.DefaultBubbleStyleID,
		profile.DefaultBubbleSkinID,
		nullStringValue(profile.PreferredModeID),
		nullStringValue(profile.PreferredMapID),
		nullStringValue(profile.PreferredRuleSetID),
		profile.ProfileVersion,
		profile.OwnedAssetRevision,
		profile.UpdatedAt,
	)
	return err
}

func (r *ProfileRepository) FindByAccountID(ctx context.Context, accountID string) (Profile, error) {
	row := r.db.QueryRowContext(
		ctx,
		`SELECT
			profile_id,
			account_id,
			nickname,
			default_character_id,
			default_character_skin_id,
			default_bubble_style_id,
			default_bubble_skin_id,
			preferred_mode_id,
			preferred_map_id,
			preferred_rule_set_id,
			profile_version,
			owned_asset_revision,
			updated_at
		FROM player_profiles
		WHERE account_id = $1`,
		accountID,
	)
	return scanProfile(row)
}

func (r *ProfileRepository) UpdateProfile(ctx context.Context, profile Profile) error {
	_, err := r.db.ExecContext(
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
	_, err := r.db.ExecContext(
		ctx,
		`UPDATE player_profiles
		SET default_character_id = $2,
			default_character_skin_id = $3,
			default_bubble_style_id = $4,
			default_bubble_skin_id = $5,
			profile_version = $6,
			updated_at = $7
		WHERE profile_id = $1`,
		profile.ProfileID,
		profile.DefaultCharacterID,
		profile.DefaultCharacterSkinID,
		profile.DefaultBubbleStyleID,
		profile.DefaultBubbleSkinID,
		profile.ProfileVersion,
		profile.UpdatedAt,
	)
	return err
}

func (r *ProfileRepository) InsertOwnedAsset(ctx context.Context, asset OwnedAsset) error {
	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO player_owned_assets (
			account_id,
			profile_id,
			asset_type,
			asset_id,
			state,
			acquired_at,
			source_type
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (profile_id, asset_type, asset_id) DO NOTHING`,
		asset.AccountID,
		asset.ProfileID,
		asset.AssetType,
		asset.AssetID,
		asset.State,
		asset.AcquiredAt,
		asset.SourceType,
	)
	return err
}

func (r *ProfileRepository) ListOwnedAssets(ctx context.Context, profileID string) ([]OwnedAsset, error) {
	rows, err := r.db.QueryContext(
		ctx,
		`SELECT
			account_id,
			profile_id,
			asset_type,
			asset_id,
			state,
			acquired_at,
			source_type
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
			&asset.AcquiredAt,
			&asset.SourceType,
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
		&profile.DefaultCharacterID,
		&profile.DefaultCharacterSkinID,
		&profile.DefaultBubbleStyleID,
		&profile.DefaultBubbleSkinID,
		&profile.PreferredModeID,
		&profile.PreferredMapID,
		&profile.PreferredRuleSetID,
		&profile.ProfileVersion,
		&profile.OwnedAssetRevision,
		&profile.UpdatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
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
