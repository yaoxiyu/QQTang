package httpapi

import (
	"net/http"

	"qqtang/services/account_service/internal/auth"
	"qqtang/services/shared/httpx"
)

type AuthHandler struct {
	authService *auth.AuthService
}

func NewAuthHandler(authService *auth.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Account        string `json:"account"`
		Password       string `json:"password"`
		Nickname       string `json:"nickname"`
		ClientPlatform string `json:"client_platform"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	result, err := h.authService.Register(r.Context(), auth.RegisterInput{
		Account:        request.Account,
		Password:       request.Password,
		Nickname:       request.Nickname,
		ClientPlatform: request.ClientPlatform,
	})
	if err != nil {
		status, code := mapError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "auth_mode": result.AuthMode, "session_state": result.SessionState, "account_id": result.AccountID, "profile_id": result.ProfileID, "display_name": result.DisplayName, "access_token": result.AccessToken, "refresh_token": result.RefreshToken, "device_session_id": result.DeviceSessionID, "access_expire_at_unix_sec": result.AccessExpireAtUnixSec, "refresh_expire_at_unix_sec": result.RefreshExpireAtUnixSec})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Account        string `json:"account"`
		Password       string `json:"password"`
		ClientPlatform string `json:"client_platform"`
		CaptchaToken   string `json:"captcha_token"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	result, err := h.authService.Login(r.Context(), auth.LoginInput{
		Account:        request.Account,
		Password:       request.Password,
		ClientPlatform: request.ClientPlatform,
		RemoteAddr:     r.RemoteAddr,
		UserAgent:      r.UserAgent(),
		CaptchaToken:   request.CaptchaToken,
	})
	if err != nil {
		status, code := mapError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "auth_mode": result.AuthMode, "session_state": result.SessionState, "account_id": result.AccountID, "profile_id": result.ProfileID, "display_name": result.DisplayName, "access_token": result.AccessToken, "refresh_token": result.RefreshToken, "device_session_id": result.DeviceSessionID, "access_expire_at_unix_sec": result.AccessExpireAtUnixSec, "refresh_expire_at_unix_sec": result.RefreshExpireAtUnixSec})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var request struct {
		RefreshToken    string `json:"refresh_token"`
		DeviceSessionID string `json:"device_session_id"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	result, err := h.authService.Refresh(r.Context(), auth.RefreshInput{
		RefreshToken:    request.RefreshToken,
		DeviceSessionID: request.DeviceSessionID,
	})
	if err != nil {
		status, code := mapError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "auth_mode": result.AuthMode, "session_state": result.SessionState, "account_id": result.AccountID, "profile_id": result.ProfileID, "display_name": result.DisplayName, "access_token": result.AccessToken, "refresh_token": result.RefreshToken, "device_session_id": result.DeviceSessionID, "access_expire_at_unix_sec": result.AccessExpireAtUnixSec, "refresh_expire_at_unix_sec": result.RefreshExpireAtUnixSec})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var request struct {
		RefreshToken    string `json:"refresh_token"`
		DeviceSessionID string `json:"device_session_id"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	if err := h.authService.Logout(r.Context(), auth.LogoutInput{
		RefreshToken:    request.RefreshToken,
		DeviceSessionID: request.DeviceSessionID,
	}); err != nil {
		status, code := mapError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "session_state": "revoked"})
}

func (h *AuthHandler) Session(w http.ResponseWriter, r *http.Request) {
	result := getAuthResult(r.Context())
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                        true,
		"account_id":                result.AccountID,
		"profile_id":                result.ProfileID,
		"display_name":              result.DisplayName,
		"auth_mode":                 result.AuthMode,
		"device_session_id":         result.DeviceSessionID,
		"access_expire_at_unix_sec": result.AccessExpireAtUnixSec,
		"session_state":             result.SessionState,
	})
}
