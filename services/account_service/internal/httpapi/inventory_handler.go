package httpapi

import (
	"errors"
	"log"
	"net/http"

	"qqtang/services/account_service/internal/inventory"
	"qqtang/services/account_service/internal/platform/httpx"
)

type InventoryHandler struct {
	inventoryService *inventory.InventoryService
}

func NewInventoryHandler(inventoryService *inventory.InventoryService) *InventoryHandler {
	return &InventoryHandler{inventoryService: inventoryService}
}

func (h *InventoryHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	result, err := h.inventoryService.GetMyInventory(r.Context(), authResult.AccountID)
	if err != nil {
		status, code := mapInventoryError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                   true,
		"profile_id":           result.ProfileID,
		"owned_asset_revision": result.OwnedAssetRevision,
		"assets":               result.Assets,
	})
}

func mapInventoryError(err error) (int, string) {
	switch {
	case errors.Is(err, inventory.ErrInventoryProfileNotFound):
		return http.StatusNotFound, err.Error()
	default:
		log.Printf("httpapi inventory internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
