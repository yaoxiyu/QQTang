package purchase

import (
	"context"
	"errors"
	"testing"

	"qqtang/services/account_service/internal/shop"
)

type fakeCatalogProvider struct {
	catalog shop.Catalog
	err     error
}

func (f fakeCatalogProvider) GetCatalog(context.Context) (shop.Catalog, error) {
	return f.catalog, f.err
}

type fakeIDIssuer struct{}

func (fakeIDIssuer) IssueOpaqueToken(prefix string) (string, error) {
	return prefix + "_id", nil
}

func TestPurchaseOfferRequiresIdempotencyKey(t *testing.T) {
	service := NewService(nil, fakeCatalogProvider{}, fakeIDIssuer{})

	_, err := service.PurchaseOffer(context.Background(), PurchaseInput{
		AccountID:               "account_1",
		OfferID:                 "offer.title.rookie",
		ExpectedCatalogRevision: 1,
	})
	if !errors.Is(err, ErrPurchaseIdempotencyRequired) {
		t.Fatalf("expected ErrPurchaseIdempotencyRequired, got %v", err)
	}
}

func TestPurchaseOfferRejectsCatalogRevisionMismatchBeforeTransaction(t *testing.T) {
	service := NewService(nil, fakeCatalogProvider{catalog: minimalCatalog()}, fakeIDIssuer{})

	_, err := service.PurchaseOffer(context.Background(), PurchaseInput{
		AccountID:               "account_1",
		OfferID:                 "offer.title.rookie",
		IdempotencyKey:          "idem_1",
		ExpectedCatalogRevision: 2,
	})
	if !errors.Is(err, ErrPurchaseCatalogRevision) {
		t.Fatalf("expected ErrPurchaseCatalogRevision, got %v", err)
	}
}

func TestPurchaseOfferRejectsMissingOfferBeforeTransaction(t *testing.T) {
	service := NewService(nil, fakeCatalogProvider{catalog: minimalCatalog()}, fakeIDIssuer{})

	_, err := service.PurchaseOffer(context.Background(), PurchaseInput{
		AccountID:               "account_1",
		OfferID:                 "missing",
		IdempotencyKey:          "idem_1",
		ExpectedCatalogRevision: 1,
	})
	if !errors.Is(err, ErrPurchaseOfferInvalid) {
		t.Fatalf("expected ErrPurchaseOfferInvalid, got %v", err)
	}
}

func minimalCatalog() shop.Catalog {
	return shop.Catalog{
		CatalogRevision: 1,
		Currencies:      []shop.Currency{{CurrencyID: "soft_gold", Enabled: true}},
		Tabs:            []shop.Tab{{TabID: "titles", Enabled: true}},
		Goods: []shop.Goods{{
			GoodsID:         "goods.title.rookie",
			GoodsType:       "asset",
			TargetAssetType: "title",
			TargetAssetID:   "title_rookie",
			Enabled:         true,
		}},
		Offers: []shop.Offer{{
			OfferID:    "offer.title.rookie",
			TabID:      "titles",
			GoodsID:    "goods.title.rookie",
			CurrencyID: "soft_gold",
			Price:      100,
			LimitType:  "once",
			Enabled:    true,
		}},
	}
}
