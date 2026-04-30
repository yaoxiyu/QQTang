package shop

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCatalogProviderLoadsAndFiltersCatalog(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "catalog.json")
	catalog := Catalog{
		CatalogRevision: 2,
		Currencies: []Currency{
			{CurrencyID: "soft_gold", Enabled: true, SortOrder: 20},
			{CurrencyID: "disabled", Enabled: false, SortOrder: 10},
		},
		Tabs:  []Tab{{TabID: "characters", Enabled: true, SortOrder: 10}},
		Goods: []Goods{{GoodsID: "goods.char", GoodsType: "asset", TargetAssetType: "character", TargetAssetID: "10101", Enabled: true, SortOrder: 10}},
		Offers: []Offer{
			{OfferID: "offer.char", TabID: "characters", GoodsID: "goods.char", CurrencyID: "soft_gold", Price: 100, Enabled: true, SortOrder: 10},
			{OfferID: "offer.disabled", TabID: "characters", GoodsID: "goods.char", CurrencyID: "soft_gold", Price: 100, Enabled: false, SortOrder: 20},
		},
	}
	raw, err := json.Marshal(catalog)
	if err != nil {
		t.Fatalf("marshal catalog: %v", err)
	}
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatalf("write catalog: %v", err)
	}

	loaded, err := NewCatalogProvider(path).GetCatalog(context.Background())
	if err != nil {
		t.Fatalf("GetCatalog returned error: %v", err)
	}
	if loaded.CatalogRevision != 2 || len(loaded.Currencies) != 1 || len(loaded.Offers) != 1 {
		t.Fatalf("unexpected filtered catalog: %+v", loaded)
	}
}

func TestValidateCatalogRejectsBrokenOfferReference(t *testing.T) {
	err := ValidateCatalog(Catalog{
		CatalogRevision: 1,
		Currencies:      []Currency{{CurrencyID: "soft_gold", Enabled: true}},
		Tabs:            []Tab{{TabID: "characters", Enabled: true}},
		Goods:           []Goods{{GoodsID: "goods.char", GoodsType: "asset", Enabled: true}},
		Offers:          []Offer{{OfferID: "offer.char", TabID: "characters", GoodsID: "missing", CurrencyID: "soft_gold", Enabled: true}},
	})
	if err == nil {
		t.Fatal("expected broken offer reference to fail")
	}
}
