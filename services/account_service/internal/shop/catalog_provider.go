package shop

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

var (
	ErrCatalogPathNotFound = errors.New("SHOP_CATALOG_PATH_NOT_FOUND")
	ErrCatalogInvalid      = errors.New("SHOP_CATALOG_INVALID")
)

const DefaultCatalogRelativePath = "content/shop/catalog/shop_catalog.json"

type Currency struct {
	CurrencyID    string `json:"currency_id"`
	DisplayName   string `json:"display_name"`
	IconUIAssetID string `json:"icon_ui_asset_id"`
	SortOrder     int    `json:"sort_order"`
	Enabled       bool   `json:"enabled"`
}

type Tab struct {
	TabID         string `json:"tab_id"`
	DisplayName   string `json:"display_name"`
	IconUIAssetID string `json:"icon_ui_asset_id"`
	SortOrder     int    `json:"sort_order"`
	Enabled       bool   `json:"enabled"`
}

type Goods struct {
	GoodsID         string `json:"goods_id"`
	GoodsType       string `json:"goods_type"`
	TargetAssetType string `json:"target_asset_type"`
	TargetAssetID   string `json:"target_asset_id"`
	DisplayName     string `json:"display_name"`
	IconUIAssetID   string `json:"icon_ui_asset_id"`
	SortOrder       int    `json:"sort_order"`
	Enabled         bool   `json:"enabled"`
}

type Offer struct {
	OfferID       string `json:"offer_id"`
	TabID         string `json:"tab_id"`
	GoodsID       string `json:"goods_id"`
	CurrencyID    string `json:"currency_id"`
	Price         int64  `json:"price"`
	LimitType     string `json:"limit_type"`
	LimitCount    int64  `json:"limit_count"`
	DisplayName   string `json:"display_name"`
	IconUIAssetID string `json:"icon_ui_asset_id"`
	SortOrder     int    `json:"sort_order"`
	Enabled       bool   `json:"enabled"`
}

type Catalog struct {
	CatalogRevision int64      `json:"catalog_revision"`
	Currencies      []Currency `json:"currencies"`
	Tabs            []Tab      `json:"tabs"`
	Goods           []Goods    `json:"goods"`
	Offers          []Offer    `json:"offers"`
}

type CatalogProvider struct {
	catalogPath string
}

func NewCatalogProvider(catalogPath string) *CatalogProvider {
	return &CatalogProvider{catalogPath: catalogPath}
}

func NewDefaultCatalogProvider() *CatalogProvider {
	return &CatalogProvider{catalogPath: DefaultCatalogRelativePath}
}

func (p *CatalogProvider) GetCatalog(ctx context.Context) (Catalog, error) {
	select {
	case <-ctx.Done():
		return Catalog{}, ctx.Err()
	default:
	}
	path, err := resolveCatalogPath(p.catalogPath)
	if err != nil {
		return Catalog{}, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return Catalog{}, err
	}
	var catalog Catalog
	if err := json.Unmarshal(raw, &catalog); err != nil {
		return Catalog{}, err
	}
	if err := ValidateCatalog(catalog); err != nil {
		return Catalog{}, err
	}
	return filterDisabled(catalog), nil
}

func ValidateCatalog(catalog Catalog) error {
	if catalog.CatalogRevision <= 0 {
		return fmt.Errorf("%w: catalog_revision must be positive", ErrCatalogInvalid)
	}
	currencyIDs := make(map[string]struct{}, len(catalog.Currencies))
	for _, currency := range catalog.Currencies {
		if currency.CurrencyID == "" {
			return fmt.Errorf("%w: currency_id is required", ErrCatalogInvalid)
		}
		currencyIDs[currency.CurrencyID] = struct{}{}
	}
	tabIDs := make(map[string]struct{}, len(catalog.Tabs))
	for _, tab := range catalog.Tabs {
		if tab.TabID == "" {
			return fmt.Errorf("%w: tab_id is required", ErrCatalogInvalid)
		}
		tabIDs[tab.TabID] = struct{}{}
	}
	goodsIDs := make(map[string]Goods, len(catalog.Goods))
	for _, goods := range catalog.Goods {
		if goods.GoodsID == "" || goods.GoodsType == "" {
			return fmt.Errorf("%w: goods identity is required", ErrCatalogInvalid)
		}
		goodsIDs[goods.GoodsID] = goods
	}
	for _, offer := range catalog.Offers {
		if offer.OfferID == "" || offer.GoodsID == "" || offer.CurrencyID == "" || offer.TabID == "" {
			return fmt.Errorf("%w: offer identity is required", ErrCatalogInvalid)
		}
		if _, ok := goodsIDs[offer.GoodsID]; !ok {
			return fmt.Errorf("%w: offer %s references missing goods %s", ErrCatalogInvalid, offer.OfferID, offer.GoodsID)
		}
		if _, ok := currencyIDs[offer.CurrencyID]; !ok {
			return fmt.Errorf("%w: offer %s references missing currency %s", ErrCatalogInvalid, offer.OfferID, offer.CurrencyID)
		}
		if _, ok := tabIDs[offer.TabID]; !ok {
			return fmt.Errorf("%w: offer %s references missing tab %s", ErrCatalogInvalid, offer.OfferID, offer.TabID)
		}
		if offer.Price < 0 {
			return fmt.Errorf("%w: offer %s has negative price", ErrCatalogInvalid, offer.OfferID)
		}
	}
	return nil
}

func (c Catalog) FindOffer(offerID string) (Offer, bool) {
	for _, offer := range c.Offers {
		if offer.OfferID == offerID {
			return offer, true
		}
	}
	return Offer{}, false
}

func (c Catalog) FindGoods(goodsID string) (Goods, bool) {
	for _, goods := range c.Goods {
		if goods.GoodsID == goodsID {
			return goods, true
		}
	}
	return Goods{}, false
}

func filterDisabled(catalog Catalog) Catalog {
	catalog.Currencies = filterCurrencies(catalog.Currencies)
	catalog.Tabs = filterTabs(catalog.Tabs)
	catalog.Goods = filterGoods(catalog.Goods)
	catalog.Offers = filterOffers(catalog.Offers)
	return catalog
}

func filterCurrencies(values []Currency) []Currency {
	result := make([]Currency, 0, len(values))
	for _, value := range values {
		if value.Enabled {
			result = append(result, value)
		}
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].SortOrder < result[j].SortOrder })
	return result
}

func filterTabs(values []Tab) []Tab {
	result := make([]Tab, 0, len(values))
	for _, value := range values {
		if value.Enabled {
			result = append(result, value)
		}
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].SortOrder < result[j].SortOrder })
	return result
}

func filterGoods(values []Goods) []Goods {
	result := make([]Goods, 0, len(values))
	for _, value := range values {
		if value.Enabled {
			result = append(result, value)
		}
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].SortOrder < result[j].SortOrder })
	return result
}

func filterOffers(values []Offer) []Offer {
	result := make([]Offer, 0, len(values))
	for _, value := range values {
		if value.Enabled {
			result = append(result, value)
		}
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].SortOrder < result[j].SortOrder })
	return result
}

func resolveCatalogPath(catalogPath string) (string, error) {
	if catalogPath == "" {
		catalogPath = DefaultCatalogRelativePath
	}
	if filepath.IsAbs(catalogPath) {
		if _, err := os.Stat(catalogPath); err == nil {
			return catalogPath, nil
		}
		return "", ErrCatalogPathNotFound
	}
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	current := wd
	for {
		candidate := filepath.Join(current, catalogPath)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}
	return "", ErrCatalogPathNotFound
}
