package httpapi

import (
	"errors"
	"log"
	"net/http"

	"qqtang/services/account_service/internal/economy"
	"qqtang/services/shared/httpx"
)

type WalletHandler struct {
	walletService *economy.WalletService
}

func NewWalletHandler(walletService *economy.WalletService) *WalletHandler {
	return &WalletHandler{walletService: walletService}
}

func (h *WalletHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	result, err := h.walletService.GetMyWallet(r.Context(), authResult.AccountID)
	if err != nil {
		status, code := mapWalletError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":              true,
		"profile_id":      result.ProfileID,
		"wallet_revision": result.WalletRevision,
		"balances":        result.Balances,
	})
}

func mapWalletError(err error) (int, string) {
	switch {
	case errors.Is(err, economy.ErrWalletProfileNotFound):
		return http.StatusNotFound, err.Error()
	default:
		log.Printf("httpapi wallet internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
