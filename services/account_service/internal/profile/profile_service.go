package profile

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"qqtang/services/account_service/internal/storage"
)

var (
	ErrProfileNotFound = errors.New("PROFILE_NOT_FOUND")
	ErrNicknameInvalid = errors.New("PROFILE_NICKNAME_INVALID")
	ErrLoadoutNotOwned = errors.New("PROFILE_LOADOUT_NOT_OWNED")
)

type Service struct {
	profileRepo *storage.ProfileRepository
}

type ProfileResponse struct {
	ProfileID              string   `json:"profile_id"`
	AccountID              string   `json:"account_id"`
	Nickname               string   `json:"nickname"`
	AvatarID               string   `json:"avatar_id"`
	TitleID                string   `json:"title_id"`
	DefaultCharacterID     string   `json:"default_character_id"`
	DefaultCharacterSkinID string   `json:"default_character_skin_id"`
	DefaultBubbleStyleID   string   `json:"default_bubble_style_id"`
	DefaultBubbleSkinID    string   `json:"default_bubble_skin_id"`
	PreferredModeID        string   `json:"preferred_mode_id"`
	PreferredMapID         string   `json:"preferred_map_id"`
	PreferredRuleSetID     string   `json:"preferred_rule_set_id"`
	OwnedCharacterIDs      []string `json:"owned_character_ids"`
	OwnedCharacterSkinIDs  []string `json:"owned_character_skin_ids"`
	OwnedBubbleStyleIDs    []string `json:"owned_bubble_style_ids"`
	OwnedBubbleSkinIDs     []string `json:"owned_bubble_skin_ids"`
	ProfileVersion         int64    `json:"profile_version"`
	OwnedAssetRevision     int64    `json:"owned_asset_revision"`
}

type UpdateProfileInput struct {
	AccountID          string
	Nickname           string
	PreferredModeID    *string
	PreferredMapID     *string
	PreferredRuleSetID *string
}

type UpdateLoadoutInput struct {
	AccountID              string
	DefaultCharacterID     string
	DefaultCharacterSkinID string
	DefaultBubbleStyleID   string
	DefaultBubbleSkinID    string
	AvatarID               *string
	TitleID                *string
}

func NewService(profileRepo *storage.ProfileRepository) *Service {
	return &Service{profileRepo: profileRepo}
}

func (s *Service) GetMyProfile(ctx context.Context, accountID string) (ProfileResponse, error) {
	profileRecord, err := s.profileRepo.FindByAccountID(ctx, accountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ProfileResponse{}, ErrProfileNotFound
		}
		return ProfileResponse{}, err
	}
	assets, err := s.profileRepo.ListOwnedAssets(ctx, profileRecord.ProfileID)
	if err != nil {
		return ProfileResponse{}, err
	}
	return toProfileResponse(profileRecord, assets), nil
}

func (s *Service) UpdateMyProfile(ctx context.Context, input UpdateProfileInput) (ProfileResponse, error) {
	profileRecord, err := s.profileRepo.FindByAccountID(ctx, input.AccountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ProfileResponse{}, ErrProfileNotFound
		}
		return ProfileResponse{}, err
	}
	nickname := strings.TrimSpace(input.Nickname)
	if nickname == "" {
		return ProfileResponse{}, ErrNicknameInvalid
	}
	profileRecord.Nickname = nickname
	if input.PreferredModeID != nil {
		profileRecord.PreferredModeID = toNullString(*input.PreferredModeID)
	}
	if input.PreferredMapID != nil {
		profileRecord.PreferredMapID = toNullString(*input.PreferredMapID)
	}
	if input.PreferredRuleSetID != nil {
		profileRecord.PreferredRuleSetID = toNullString(*input.PreferredRuleSetID)
	}
	profileRecord.ProfileVersion++
	profileRecord.UpdatedAt = time.Now().UTC()
	if err := s.profileRepo.UpdateProfile(ctx, profileRecord); err != nil {
		return ProfileResponse{}, err
	}
	return s.GetMyProfile(ctx, input.AccountID)
}

func (s *Service) UpdateMyLoadout(ctx context.Context, input UpdateLoadoutInput) (ProfileResponse, error) {
	profileRecord, err := s.profileRepo.FindByAccountID(ctx, input.AccountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ProfileResponse{}, ErrProfileNotFound
		}
		return ProfileResponse{}, err
	}
	ownedAssets, err := s.profileRepo.ListOwnedAssets(ctx, profileRecord.ProfileID)
	if err != nil {
		return ProfileResponse{}, err
	}
	ownedLookup := make(map[string]map[string]struct{})
	for _, asset := range ownedAssets {
		if _, ok := ownedLookup[asset.AssetType]; !ok {
			ownedLookup[asset.AssetType] = make(map[string]struct{})
		}
		ownedLookup[asset.AssetType][asset.AssetID] = struct{}{}
	}
	if !isOwned(ownedLookup, "character", input.DefaultCharacterID) ||
		!isOwned(ownedLookup, "character_skin", input.DefaultCharacterSkinID) ||
		!isOwned(ownedLookup, "bubble", input.DefaultBubbleStyleID) ||
		!isOwned(ownedLookup, "bubble_skin", input.DefaultBubbleSkinID) {
		return ProfileResponse{}, ErrLoadoutNotOwned
	}
	if input.AvatarID != nil && !isOptionalOwned(ownedLookup, "avatar", *input.AvatarID) {
		return ProfileResponse{}, ErrLoadoutNotOwned
	}
	if input.TitleID != nil && !isOptionalOwned(ownedLookup, "title", *input.TitleID) {
		return ProfileResponse{}, ErrLoadoutNotOwned
	}
	profileRecord.DefaultCharacterID = input.DefaultCharacterID
	profileRecord.DefaultCharacterSkinID = input.DefaultCharacterSkinID
	profileRecord.DefaultBubbleStyleID = input.DefaultBubbleStyleID
	profileRecord.DefaultBubbleSkinID = input.DefaultBubbleSkinID
	if input.AvatarID != nil {
		profileRecord.AvatarID = toNullString(*input.AvatarID)
	}
	if input.TitleID != nil {
		profileRecord.TitleID = toNullString(*input.TitleID)
	}
	profileRecord.ProfileVersion++
	profileRecord.UpdatedAt = time.Now().UTC()
	if err := s.profileRepo.UpdateLoadout(ctx, profileRecord); err != nil {
		return ProfileResponse{}, err
	}
	return s.GetMyProfile(ctx, input.AccountID)
}

func toProfileResponse(profileRecord storage.Profile, assets []storage.OwnedAsset) ProfileResponse {
	resp := ProfileResponse{
		ProfileID:              profileRecord.ProfileID,
		AccountID:              profileRecord.AccountID,
		Nickname:               profileRecord.Nickname,
		AvatarID:               nullableString(profileRecord.AvatarID),
		TitleID:                nullableString(profileRecord.TitleID),
		DefaultCharacterID:     profileRecord.DefaultCharacterID,
		DefaultCharacterSkinID: profileRecord.DefaultCharacterSkinID,
		DefaultBubbleStyleID:   profileRecord.DefaultBubbleStyleID,
		DefaultBubbleSkinID:    profileRecord.DefaultBubbleSkinID,
		PreferredModeID:        nullableString(profileRecord.PreferredModeID),
		PreferredMapID:         nullableString(profileRecord.PreferredMapID),
		PreferredRuleSetID:     nullableString(profileRecord.PreferredRuleSetID),
		OwnedCharacterIDs:      make([]string, 0),
		OwnedCharacterSkinIDs:  make([]string, 0),
		OwnedBubbleStyleIDs:    make([]string, 0),
		OwnedBubbleSkinIDs:     make([]string, 0),
		ProfileVersion:         profileRecord.ProfileVersion,
		OwnedAssetRevision:     profileRecord.OwnedAssetRevision,
	}
	for _, asset := range assets {
		switch asset.AssetType {
		case "character":
			resp.OwnedCharacterIDs = append(resp.OwnedCharacterIDs, asset.AssetID)
		case "character_skin":
			resp.OwnedCharacterSkinIDs = append(resp.OwnedCharacterSkinIDs, asset.AssetID)
		case "bubble":
			resp.OwnedBubbleStyleIDs = append(resp.OwnedBubbleStyleIDs, asset.AssetID)
		case "bubble_skin":
			resp.OwnedBubbleSkinIDs = append(resp.OwnedBubbleSkinIDs, asset.AssetID)
		}
	}
	return resp
}

func nullableString(value sql.NullString) string {
	if !value.Valid {
		return ""
	}
	return value.String
}

func toNullString(value string) sql.NullString {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return sql.NullString{}
	}
	return sql.NullString{String: trimmed, Valid: true}
}

func isOwned(lookup map[string]map[string]struct{}, assetType string, assetID string) bool {
	assets, ok := lookup[assetType]
	if !ok {
		return false
	}
	_, ok = assets[assetID]
	return ok
}

func isOptionalOwned(lookup map[string]map[string]struct{}, assetType string, assetID string) bool {
	trimmed := strings.TrimSpace(assetID)
	if trimmed == "" {
		return true
	}
	return isOwned(lookup, assetType, trimmed)
}
