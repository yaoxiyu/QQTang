package httpapi

import (
	"errors"
	"log"
	"net/http"

	"qqtang/services/shared/httpx"
	"qqtang/services/account_service/internal/purchase"
)

type PurchaseHandler struct {
	purchaseService *purchase.Service
}

func NewPurchaseHandler(purchaseService *purchase.Service) *PurchaseHandler {
	return &PurchaseHandler{purchaseService: purchaseService}
}

func (h *PurchaseHandler) PurchaseOffer(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	var request struct {
		OfferID                 string `json:"offer_id"`
		IdempotencyKey          string `json:"idempotency_key"`
		ExpectedCatalogRevision int64  `json:"expected_catalog_revision"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	result, err := h.purchaseService.PurchaseOffer(r.Context(), purchase.PurchaseInput{
		AccountID:               authResult.AccountID,
		OfferID:                 request.OfferID,
		IdempotencyKey:          request.IdempotencyKey,
		ExpectedCatalogRevision: request.ExpectedCatalogRevision,
	})
	if err != nil {
		status, code := mapPurchaseError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                   true,
		"purchase_id":          result.PurchaseID,
		"offer_id":             result.OfferID,
		"catalog_revision":     result.CatalogRevision,
		"status":               result.Status,
		"wallet":               result.Wallet,
		"inventory":            result.Inventory,
		"profile_version":      result.ProfileVersion,
		"owned_asset_revision": result.OwnedAssetRevision,
		"wallet_revision":      result.WalletRevision,
		"idempotent_replay":    result.IdempotentReplay,
	})
}

func mapPurchaseError(err error) (int, string) {
	switch {
	case errors.Is(err, purchase.ErrPurchaseIdempotencyRequired),
		errors.Is(err, purchase.ErrPurchaseOfferInvalid):
		return http.StatusBadRequest, err.Error()
	case errors.Is(err, purchase.ErrPurchaseProfileNotFound):
		return http.StatusNotFound, err.Error()
	case errors.Is(err, purchase.ErrPurchaseCatalogRevision),
		errors.Is(err, purchase.ErrPurchaseInsufficientFunds),
		errors.Is(err, purchase.ErrPurchaseAlreadyOwned),
		errors.Is(err, purchase.ErrPurchaseIdempotencyConflict):
		return http.StatusConflict, err.Error()
	default:
		log.Printf("httpapi purchase internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
