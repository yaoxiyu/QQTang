package auth

import (
	"strings"
	"time"

	"qqtang/services/account_service/internal/storage"
)

const (
	defaultCharacterID     = "10101"
	defaultCharacterSkinID = "skin_gold"
	defaultBubbleStyleID   = "bubble_round"
	defaultBubbleSkinID    = "bubble_skin_gold"
)

var defaultFreeCharacterIDs = []string{
	"10101",
	"10201",
	"10301",
	"10401",
	"10501",
	"10601",
	"10701",
	"10801",
	"10901",
	"11001",
	"11101",
	"11301",
	"11401",
	"11501",
	"11601",
	"11701",
	"11801",
	"11901",
	"12001",
	"12101",
	"12201",
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
