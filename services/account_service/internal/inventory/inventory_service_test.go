package inventory

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	"qqtang/services/account_service/internal/storage"
)

type fakeProfileLookup struct {
	profile storage.Profile
	err     error
}

func (f fakeProfileLookup) FindByAccountID(context.Context, string) (storage.Profile, error) {
	return f.profile, f.err
}

type fakeAssetReader struct {
	assets []storage.OwnedAsset
	err    error
}

func (f fakeAssetReader) ListAssets(context.Context, string) ([]storage.OwnedAsset, error) {
	return f.assets, f.err
}

func TestInventoryServiceGetMyInventoryReturnsAssets(t *testing.T) {
	now := time.Date(2026, 4, 26, 1, 2, 3, 0, time.UTC)
	service := NewInventoryService(
		fakeProfileLookup{profile: storage.Profile{ProfileID: "profile_1", OwnedAssetRevision: 7}},
		fakeAssetReader{assets: []storage.OwnedAsset{
			{
				ProfileID:   "profile_1",
				AssetType:   "character",
				AssetID:     "10101",
				State:       "owned",
				Quantity:    1,
				AcquiredAt:  now,
				SourceType:  "system",
				SourceRefID: sql.NullString{String: "bootstrap", Valid: true},
				Revision:    2,
			},
		}},
	)

	result, err := service.GetMyInventory(context.Background(), "account_1")
	if err != nil {
		t.Fatalf("GetMyInventory returned error: %v", err)
	}
	if result.ProfileID != "profile_1" || result.OwnedAssetRevision != 7 {
		t.Fatalf("unexpected inventory identity: %+v", result)
	}
	if len(result.Assets) != 1 {
		t.Fatalf("expected one asset, got %+v", result.Assets)
	}
	asset := result.Assets[0]
	if asset.AssetType != "character" || asset.AssetID != "10101" || asset.SourceRefID != "bootstrap" || asset.Revision != 2 {
		t.Fatalf("unexpected asset response: %+v", asset)
	}
}

func TestInventoryServiceMapsMissingProfile(t *testing.T) {
	service := NewInventoryService(
		fakeProfileLookup{err: storage.ErrNotFound},
		fakeAssetReader{},
	)

	_, err := service.GetMyInventory(context.Background(), "missing")
	if !errors.Is(err, ErrInventoryProfileNotFound) {
		t.Fatalf("expected ErrInventoryProfileNotFound, got %v", err)
	}
}
