package inventory

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"qqtang/services/account_service/internal/storage"
)

var ErrInventoryProfileNotFound = errors.New("INVENTORY_PROFILE_NOT_FOUND")

type ProfileLookup interface {
	FindByAccountID(ctx context.Context, accountID string) (storage.Profile, error)
}

type AssetReader interface {
	ListAssets(ctx context.Context, profileID string) ([]storage.OwnedAsset, error)
}

type InventoryService struct {
	profileRepo ProfileLookup
	assetRepo   AssetReader
}

type AssetResponse struct {
	AssetType   string  `json:"asset_type"`
	AssetID     string  `json:"asset_id"`
	State       string  `json:"state"`
	Quantity    int64   `json:"quantity"`
	AcquiredAt  string  `json:"acquired_at"`
	ExpireAt    *string `json:"expire_at"`
	SourceType  string  `json:"source_type"`
	SourceRefID string  `json:"source_ref_id"`
	Revision    int64   `json:"revision"`
}

type InventoryResponse struct {
	ProfileID          string          `json:"profile_id"`
	OwnedAssetRevision int64           `json:"owned_asset_revision"`
	Assets             []AssetResponse `json:"assets"`
}

func NewInventoryService(profileRepo ProfileLookup, assetRepo AssetReader) *InventoryService {
	return &InventoryService{
		profileRepo: profileRepo,
		assetRepo:   assetRepo,
	}
}

func (s *InventoryService) GetMyInventory(ctx context.Context, accountID string) (InventoryResponse, error) {
	profileRecord, err := s.profileRepo.FindByAccountID(ctx, accountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return InventoryResponse{}, ErrInventoryProfileNotFound
		}
		return InventoryResponse{}, err
	}
	assets, err := s.assetRepo.ListAssets(ctx, profileRecord.ProfileID)
	if err != nil {
		return InventoryResponse{}, err
	}
	return ToInventoryResponse(profileRecord, assets), nil
}

func ToInventoryResponse(profileRecord storage.Profile, assets []storage.OwnedAsset) InventoryResponse {
	response := InventoryResponse{
		ProfileID:          profileRecord.ProfileID,
		OwnedAssetRevision: profileRecord.OwnedAssetRevision,
		Assets:             make([]AssetResponse, 0, len(assets)),
	}
	for _, asset := range assets {
		var expireAt *string
		if asset.ExpireAt.Valid {
			value := formatTime(asset.ExpireAt.Time)
			expireAt = &value
		}
		response.Assets = append(response.Assets, AssetResponse{
			AssetType:   asset.AssetType,
			AssetID:     asset.AssetID,
			State:       asset.State,
			Quantity:    asset.Quantity,
			AcquiredAt:  formatTime(asset.AcquiredAt),
			ExpireAt:    expireAt,
			SourceType:  asset.SourceType,
			SourceRefID: nullString(asset.SourceRefID),
			Revision:    asset.Revision,
		})
	}
	return response
}

func formatTime(value time.Time) string {
	if value.IsZero() {
		return ""
	}
	return value.UTC().Format(time.RFC3339Nano)
}

func nullString(value sql.NullString) string {
	if !value.Valid {
		return ""
	}
	return value.String
}
