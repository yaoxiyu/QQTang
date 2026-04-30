package auth

import (
	"strings"
	"time"

	"qqtang/services/account_service/internal/storage"
)

const (
	defaultCharacterID     = "char_11001"
	defaultCharacterSkinID = "skin_gold"
	defaultBubbleStyleID   = "bubble_round"
	defaultBubbleSkinID    = "bubble_skin_gold"
)

var defaultFreeCharacterIDs = []string{
	"char_11001",
	"char_12001",
	"char_13001",
	"char_14001",
	"char_15001",
	"char_16001",
	"char_17001",
	"char_19001",
}

func defaultRegistrationAssets(accountID string, profileID string, acquiredAt time.Time) []storage.OwnedAsset {
	assets := make([]storage.OwnedAsset, 0, len(defaultFreeCharacterIDs)+3)
	for _, characterID := range defaultFreeCharacterIDs {
		characterID = strings.TrimSpace(characterID)
		if characterID == "" {
			continue
		}
		assets = append(assets, storage.OwnedAsset{
			AccountID:  accountID,
			ProfileID:  profileID,
			AssetType:  "character",
			AssetID:    characterID,
			State:      "owned",
			AcquiredAt: acquiredAt,
			SourceType: "registration_default",
		})
	}
	assets = append(assets,
		storage.OwnedAsset{AccountID: accountID, ProfileID: profileID, AssetType: "character_skin", AssetID: defaultCharacterSkinID, State: "owned", AcquiredAt: acquiredAt, SourceType: "registration_default"},
		storage.OwnedAsset{AccountID: accountID, ProfileID: profileID, AssetType: "bubble", AssetID: defaultBubbleStyleID, State: "owned", AcquiredAt: acquiredAt, SourceType: "registration_default"},
		storage.OwnedAsset{AccountID: accountID, ProfileID: profileID, AssetType: "bubble_skin", AssetID: defaultBubbleSkinID, State: "owned", AcquiredAt: acquiredAt, SourceType: "registration_default"},
	)
	return assets
}
