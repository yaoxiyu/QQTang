package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"qqtang/services/account_service/internal/profile"
)

type ProfileHandler struct {
	profileService *profile.Service
}

func NewProfileHandler(profileService *profile.Service) *ProfileHandler {
	return &ProfileHandler{profileService: profileService}
}

func (h *ProfileHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	result, err := h.profileService.GetMyProfile(r.Context(), authResult.AccountID)
	if err != nil {
		status, code := mapProfileError(err)
		writeError(w, status, code, code)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                        true,
		"profile_id":                result.ProfileID,
		"account_id":                result.AccountID,
		"nickname":                  result.Nickname,
		"default_character_id":      result.DefaultCharacterID,
		"default_character_skin_id": result.DefaultCharacterSkinID,
		"default_bubble_style_id":   result.DefaultBubbleStyleID,
		"default_bubble_skin_id":    result.DefaultBubbleSkinID,
		"preferred_mode_id":         result.PreferredModeID,
		"preferred_map_id":          result.PreferredMapID,
		"preferred_rule_set_id":     result.PreferredRuleSetID,
		"owned_character_ids":       result.OwnedCharacterIDs,
		"owned_character_skin_ids":  result.OwnedCharacterSkinIDs,
		"owned_bubble_style_ids":    result.OwnedBubbleStyleIDs,
		"owned_bubble_skin_ids":     result.OwnedBubbleSkinIDs,
		"profile_version":           result.ProfileVersion,
		"owned_asset_revision":      result.OwnedAssetRevision,
	})
}

func (h *ProfileHandler) PatchMe(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	var request struct {
		Nickname           string  `json:"nickname"`
		PreferredModeID    *string `json:"preferred_mode_id"`
		PreferredMapID     *string `json:"preferred_map_id"`
		PreferredRuleSetID *string `json:"preferred_rule_set_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}
	result, err := h.profileService.UpdateMyProfile(r.Context(), profile.UpdateProfileInput{
		AccountID:          authResult.AccountID,
		Nickname:           request.Nickname,
		PreferredModeID:    request.PreferredModeID,
		PreferredMapID:     request.PreferredMapID,
		PreferredRuleSetID: request.PreferredRuleSetID,
	})
	if err != nil {
		status, code := mapProfileError(err)
		writeError(w, status, code, code)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                   true,
		"profile_id":           result.ProfileID,
		"profile_version":      result.ProfileVersion,
		"owned_asset_revision": result.OwnedAssetRevision,
	})
}

func (h *ProfileHandler) PatchLoadout(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	var request struct {
		DefaultCharacterID     string `json:"default_character_id"`
		DefaultCharacterSkinID string `json:"default_character_skin_id"`
		DefaultBubbleStyleID   string `json:"default_bubble_style_id"`
		DefaultBubbleSkinID    string `json:"default_bubble_skin_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}
	result, err := h.profileService.UpdateMyLoadout(r.Context(), profile.UpdateLoadoutInput{
		AccountID:              authResult.AccountID,
		DefaultCharacterID:     request.DefaultCharacterID,
		DefaultCharacterSkinID: request.DefaultCharacterSkinID,
		DefaultBubbleStyleID:   request.DefaultBubbleStyleID,
		DefaultBubbleSkinID:    request.DefaultBubbleSkinID,
	})
	if err != nil {
		status, code := mapProfileError(err)
		writeError(w, status, code, code)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                        true,
		"profile_id":                result.ProfileID,
		"default_character_id":      result.DefaultCharacterID,
		"default_character_skin_id": result.DefaultCharacterSkinID,
		"default_bubble_style_id":   result.DefaultBubbleStyleID,
		"default_bubble_skin_id":    result.DefaultBubbleSkinID,
		"profile_version":           result.ProfileVersion,
		"owned_asset_revision":      result.OwnedAssetRevision,
	})
}

func mapProfileError(err error) (int, string) {
	switch {
	case errors.Is(err, profile.ErrProfileNotFound):
		return http.StatusNotFound, err.Error()
	case errors.Is(err, profile.ErrNicknameInvalid):
		return http.StatusBadRequest, err.Error()
	case errors.Is(err, profile.ErrLoadoutNotOwned):
		return http.StatusConflict, err.Error()
	default:
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
