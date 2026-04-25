package purchase

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/account_service/internal/economy"
	"qqtang/services/account_service/internal/inventory"
	"qqtang/services/account_service/internal/shop"
	"qqtang/services/account_service/internal/storage"
)

var (
	ErrPurchaseProfileNotFound     = errors.New("PURCHASE_PROFILE_NOT_FOUND")
	ErrPurchaseOfferInvalid        = errors.New("PURCHASE_OFFER_INVALID")
	ErrPurchaseCatalogRevision     = errors.New("PURCHASE_CATALOG_REVISION_MISMATCH")
	ErrPurchaseInsufficientFunds   = errors.New("PURCHASE_INSUFFICIENT_FUNDS")
	ErrPurchaseAlreadyOwned        = errors.New("PURCHASE_ALREADY_OWNED")
	ErrPurchaseIdempotencyRequired = errors.New("PURCHASE_IDEMPOTENCY_REQUIRED")
	ErrPurchaseIdempotencyConflict = errors.New("PURCHASE_IDEMPOTENCY_CONFLICT")
)

type IDIssuer interface {
	IssueOpaqueToken(prefix string) (string, error)
}

type CatalogProvider interface {
	GetCatalog(ctx context.Context) (shop.Catalog, error)
}

type Service struct {
	pool            *pgxpool.Pool
	catalogProvider CatalogProvider
	idIssuer        IDIssuer
}

type PurchaseInput struct {
	AccountID               string
	OfferID                 string
	IdempotencyKey          string
	ExpectedCatalogRevision int64
}

type PurchaseResult struct {
	PurchaseID         string                      `json:"purchase_id"`
	OfferID            string                      `json:"offer_id"`
	CatalogRevision    int64                       `json:"catalog_revision"`
	Status             string                      `json:"status"`
	Wallet             economy.WalletResponse      `json:"wallet"`
	Inventory          inventory.InventoryResponse `json:"inventory"`
	ProfileVersion     int64                       `json:"profile_version"`
	OwnedAssetRevision int64                       `json:"owned_asset_revision"`
	WalletRevision     int64                       `json:"wallet_revision"`
	IdempotentReplay   bool                        `json:"idempotent_replay"`
}

func NewService(pool *pgxpool.Pool, catalogProvider CatalogProvider, idIssuer IDIssuer) *Service {
	return &Service{
		pool:            pool,
		catalogProvider: catalogProvider,
		idIssuer:        idIssuer,
	}
}

func (s *Service) PurchaseOffer(ctx context.Context, input PurchaseInput) (PurchaseResult, error) {
	idempotencyKey := strings.TrimSpace(input.IdempotencyKey)
	if idempotencyKey == "" {
		return PurchaseResult{}, ErrPurchaseIdempotencyRequired
	}
	offerID := strings.TrimSpace(input.OfferID)
	if offerID == "" {
		return PurchaseResult{}, ErrPurchaseOfferInvalid
	}

	catalog, err := s.catalogProvider.GetCatalog(ctx)
	if err != nil {
		return PurchaseResult{}, err
	}
	if input.ExpectedCatalogRevision != catalog.CatalogRevision {
		return PurchaseResult{}, ErrPurchaseCatalogRevision
	}
	offer, ok := catalog.FindOffer(offerID)
	if !ok || !offer.Enabled {
		return PurchaseResult{}, ErrPurchaseOfferInvalid
	}
	goods, ok := catalog.FindGoods(offer.GoodsID)
	if !ok || !goods.Enabled || goods.GoodsType != "asset" {
		return PurchaseResult{}, ErrPurchaseOfferInvalid
	}

	var result PurchaseResult
	err = s.runInTx(ctx, func(tx pgx.Tx) error {
		profileRepo := storage.NewProfileRepository(tx)
		walletRepo := storage.NewWalletRepository(tx)
		inventoryRepo := storage.NewInventoryRepository(tx)
		purchaseRepo := storage.NewPurchaseRepository(tx)

		profileRecord, err := profileRepo.FindByAccountID(ctx, input.AccountID)
		if err != nil {
			if errors.Is(err, storage.ErrNotFound) {
				return ErrPurchaseProfileNotFound
			}
			return err
		}

		existingOrder, err := purchaseRepo.FindOrderByIdempotencyKey(ctx, profileRecord.ProfileID, idempotencyKey)
		if err == nil {
			if existingOrder.OfferID != offerID || existingOrder.CatalogRevision != input.ExpectedCatalogRevision {
				return ErrPurchaseIdempotencyConflict
			}
			existingResult, err := decodePurchaseResult(existingOrder.ResultJSON)
			if err != nil {
				return err
			}
			existingResult.IdempotentReplay = true
			result = existingResult
			return nil
		}
		if err != nil && !errors.Is(err, storage.ErrNotFound) {
			return err
		}

		owned, err := inventoryRepo.HasUsableAsset(ctx, profileRecord.ProfileID, goods.TargetAssetType, goods.TargetAssetID, time.Now().UTC())
		if err != nil {
			return err
		}
		if owned && offer.LimitType == "once" {
			return ErrPurchaseAlreadyOwned
		}

		now := time.Now().UTC()
		purchaseID, err := s.issueID("purchase")
		if err != nil {
			return err
		}
		requestJSON, err := json.Marshal(map[string]any{
			"offer_id":                  offerID,
			"idempotency_key":           idempotencyKey,
			"expected_catalog_revision": input.ExpectedCatalogRevision,
		})
		if err != nil {
			return err
		}
		if err := purchaseRepo.InsertOrder(ctx, storage.PurchaseOrder{
			PurchaseID:      purchaseID,
			ProfileID:       profileRecord.ProfileID,
			OfferID:         offerID,
			CatalogRevision: catalog.CatalogRevision,
			CurrencyID:      offer.CurrencyID,
			Price:           offer.Price,
			Status:          "pending",
			IdempotencyKey:  idempotencyKey,
			RequestJSON:     requestJSON,
			ResultJSON:      json.RawMessage(`{}`),
			CreatedAt:       now,
			CompletedAt:     sql.NullTime{},
		}); err != nil {
			return err
		}

		balance, err := walletRepo.DebitBalance(ctx, profileRecord.ProfileID, offer.CurrencyID, offer.Price, now)
		if err != nil {
			if errors.Is(err, storage.ErrNotFound) {
				return ErrPurchaseInsufficientFunds
			}
			return err
		}
		walletRevision, err := walletRepo.BumpProfileWalletRevision(ctx, profileRecord.ProfileID)
		if err != nil {
			return err
		}
		ledgerID, err := s.issueID("ledger")
		if err != nil {
			return err
		}
		if err := walletRepo.InsertLedgerEntry(ctx, storage.WalletLedgerEntry{
			LedgerID:       ledgerID,
			ProfileID:      profileRecord.ProfileID,
			CurrencyID:     offer.CurrencyID,
			Delta:          -offer.Price,
			BalanceAfter:   balance.Balance,
			Reason:         "purchase",
			RefType:        "purchase_order",
			RefID:          purchaseID,
			IdempotencyKey: idempotencyKey,
			CreatedAt:      now,
		}); err != nil {
			return err
		}

		if err := inventoryRepo.GrantAsset(ctx, storage.OwnedAsset{
			AccountID:   profileRecord.AccountID,
			ProfileID:   profileRecord.ProfileID,
			AssetType:   goods.TargetAssetType,
			AssetID:     goods.TargetAssetID,
			State:       "owned",
			Quantity:    1,
			AcquiredAt:  now,
			ExpireAt:    sql.NullTime{},
			SourceType:  "purchase",
			SourceRefID: sql.NullString{String: purchaseID, Valid: true},
			Revision:    1,
		}); err != nil {
			return err
		}
		ownedAssetRevision, err := inventoryRepo.BumpProfileOwnedAssetRevision(ctx, profileRecord.ProfileID)
		if err != nil {
			return err
		}

		profileRecord.WalletRevision = walletRevision
		profileRecord.OwnedAssetRevision = ownedAssetRevision
		balances, err := walletRepo.ListBalances(ctx, profileRecord.ProfileID)
		if err != nil {
			return err
		}
		assets, err := inventoryRepo.ListAssets(ctx, profileRecord.ProfileID)
		if err != nil {
			return err
		}
		result = PurchaseResult{
			PurchaseID:         purchaseID,
			OfferID:            offerID,
			CatalogRevision:    catalog.CatalogRevision,
			Status:             "completed",
			Wallet:             economy.ToWalletResponse(profileRecord, balances),
			Inventory:          inventory.ToInventoryResponse(profileRecord, assets),
			ProfileVersion:     profileRecord.ProfileVersion,
			OwnedAssetRevision: ownedAssetRevision,
			WalletRevision:     walletRevision,
			IdempotentReplay:   false,
		}
		resultJSON, err := json.Marshal(result)
		if err != nil {
			return err
		}
		if err := purchaseRepo.CompleteOrder(ctx, purchaseID, resultJSON, now); err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return PurchaseResult{}, err
	}
	return result, nil
}

func (s *Service) runInTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	return tx.Commit(ctx)
}

func (s *Service) issueID(prefix string) (string, error) {
	if s.idIssuer == nil {
		return "", fmt.Errorf("purchase id issuer missing")
	}
	return s.idIssuer.IssueOpaqueToken(prefix)
}

func decodePurchaseResult(raw json.RawMessage) (PurchaseResult, error) {
	if len(raw) == 0 {
		return PurchaseResult{}, ErrPurchaseIdempotencyConflict
	}
	var result PurchaseResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return PurchaseResult{}, err
	}
	if result.PurchaseID == "" {
		return PurchaseResult{}, ErrPurchaseIdempotencyConflict
	}
	return result, nil
}
