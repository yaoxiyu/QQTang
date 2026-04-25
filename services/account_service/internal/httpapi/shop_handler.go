package httpapi

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"qqtang/services/account_service/internal/platform/httpx"
	"qqtang/services/account_service/internal/shop"
)

type ShopHandler struct {
	catalogProvider *shop.CatalogProvider
}

func NewShopHandler(catalogProvider *shop.CatalogProvider) *ShopHandler {
	return &ShopHandler{catalogProvider: catalogProvider}
}

func (h *ShopHandler) GetCatalog(w http.ResponseWriter, r *http.Request) {
	catalog, err := h.catalogProvider.GetCatalog(r.Context())
	if err != nil {
		status, code := mapShopError(err)
		httpx.WriteError(w, status, code, code)
		return
	}
	ifNoneMatch := r.URL.Query().Get("if_none_match")
	if ifNoneMatch != "" {
		expectedRevision, err := strconv.ParseInt(ifNoneMatch, 10, 64)
		if err == nil && expectedRevision == catalog.CatalogRevision {
			httpx.WriteJSON(w, http.StatusOK, map[string]any{
				"ok":               true,
				"not_modified":     true,
				"catalog_revision": catalog.CatalogRevision,
			})
			return
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"catalog_revision": catalog.CatalogRevision,
		"currencies":       catalog.Currencies,
		"tabs":             catalog.Tabs,
		"goods":            catalog.Goods,
		"offers":           catalog.Offers,
	})
}

func mapShopError(err error) (int, string) {
	switch {
	case errors.Is(err, shop.ErrCatalogPathNotFound):
		return http.StatusServiceUnavailable, err.Error()
	case errors.Is(err, shop.ErrCatalogInvalid):
		return http.StatusInternalServerError, err.Error()
	default:
		log.Printf("httpapi shop internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
