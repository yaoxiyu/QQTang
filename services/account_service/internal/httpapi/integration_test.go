package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"qqtang/services/account_service/internal/auth"
	"qqtang/services/account_service/internal/economy"
	"qqtang/services/account_service/internal/inventory"
	"qqtang/services/account_service/internal/profile"
	"qqtang/services/account_service/internal/purchase"
	"qqtang/services/account_service/internal/shop"
	"qqtang/services/account_service/internal/storage"
	"qqtang/services/account_service/internal/ticket"
)

const defaultTestPostgresDSN = "postgres://qqtang_test:qqtang_test_pass@127.0.0.1:54330/qqtang_account_test?sslmode=disable"

func TestAuthLifecycleIntegration(t *testing.T) {
	env := newIntegrationEnv(t)
	t.Cleanup(env.cleanup)

	mustResetDatabase(t, env.store.Pool)

	server := httptest.NewServer(env.router)
	defer server.Close()

	mustExpectStatus(t, http.MethodGet, server.URL+"/healthz", nil, nil, http.StatusOK, nil)
	mustExpectStatus(t, http.MethodGet, server.URL+"/readyz", nil, nil, http.StatusOK, nil)
	mustExpectTextContains(t, http.MethodGet, server.URL+"/register", http.StatusOK, "注册账号")

	account := fmt.Sprintf("itest_%d", time.Now().UnixNano())
	var registerResp authPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/register", map[string]any{
		"account":         account,
		"password":        "12345678",
		"nickname":        account,
		"client_platform": "windows",
	}, nil, http.StatusOK, &registerResp)
	if registerResp.AccountID == "" || registerResp.ProfileID == "" || registerResp.RefreshToken == "" {
		t.Fatalf("register response missing identifiers: %+v", registerResp)
	}

	var loginResp authPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/login", map[string]any{
		"account":         account,
		"password":        "12345678",
		"client_platform": "windows",
	}, nil, http.StatusOK, &loginResp)
	if loginResp.DeviceSessionID == "" {
		t.Fatalf("login response missing device session id: %+v", loginResp)
	}

	var refreshResp authPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/refresh", map[string]any{
		"refresh_token":     loginResp.RefreshToken,
		"device_session_id": loginResp.DeviceSessionID,
	}, nil, http.StatusOK, &refreshResp)

	authHeader := map[string]string{
		"Authorization": "Bearer " + refreshResp.AccessToken,
	}

	var profileResp profilePayload
	mustExpectStatus(t, http.MethodGet, server.URL+"/api/v1/profile/me", nil, authHeader, http.StatusOK, &profileResp)
	if len(profileResp.OwnedCharacterIDs) == 0 || profileResp.DefaultCharacterID == "" {
		t.Fatalf("profile response missing defaults: %+v", profileResp)
	}
	if profileResp.DefaultCharacterID != "10101" || len(profileResp.OwnedCharacterIDs) != 21 {
		t.Fatalf("expected 21 QQTang free characters with 10101 default, got default=%s owned=%v", profileResp.DefaultCharacterID, profileResp.OwnedCharacterIDs)
	}

	var walletResp walletPayload
	mustExpectStatus(t, http.MethodGet, server.URL+"/api/v1/wallet/me", nil, authHeader, http.StatusOK, &walletResp)
	if walletResp.ProfileID != profileResp.ProfileID || walletResp.WalletRevision < 0 || walletResp.Balances == nil {
		t.Fatalf("wallet response missing state: %+v", walletResp)
	}

	var inventoryResp inventoryPayload
	mustExpectStatus(t, http.MethodGet, server.URL+"/api/v1/inventory/me", nil, authHeader, http.StatusOK, &inventoryResp)
	if inventoryResp.ProfileID != profileResp.ProfileID || len(inventoryResp.Assets) == 0 {
		t.Fatalf("inventory response missing assets: %+v", inventoryResp)
	}

	var shopResp shopCatalogPayload
	mustExpectStatus(t, http.MethodGet, server.URL+"/api/v1/shop/catalog", nil, authHeader, http.StatusOK, &shopResp)
	if shopResp.CatalogRevision <= 0 || len(shopResp.Currencies) == 0 || len(shopResp.Tabs) == 0 || len(shopResp.Goods) == 0 || len(shopResp.Offers) == 0 {
		t.Fatalf("shop catalog response missing content: %+v", shopResp)
	}

	var shopCachedResp shopCatalogPayload
	mustExpectStatus(t, http.MethodGet, fmt.Sprintf("%s/api/v1/shop/catalog?if_none_match=%d", server.URL, shopResp.CatalogRevision), nil, authHeader, http.StatusOK, &shopCachedResp)
	if !shopCachedResp.NotModified {
		t.Fatalf("expected not_modified shop response, got %+v", shopCachedResp)
	}

	seedWalletBalance(t, env.store.Pool, profileResp.ProfileID, "soft_gold", 500)
	var purchaseResp purchasePayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.title.rookie",
		"idempotency_key":           "itest-title-rookie",
		"expected_catalog_revision": shopResp.CatalogRevision,
	}, authHeader, http.StatusOK, &purchaseResp)
	if purchaseResp.PurchaseID == "" || purchaseResp.Status != "completed" || purchaseResp.WalletRevision <= 0 || purchaseResp.OwnedAssetRevision <= 0 {
		t.Fatalf("purchase response missing completed state: %+v", purchaseResp)
	}
	if !purchaseResp.Inventory.HasAsset("title", "title_rookie") {
		t.Fatalf("purchase did not grant title asset: %+v", purchaseResp.Inventory)
	}
	if got := purchaseResp.Wallet.BalanceOf("soft_gold"); got != 400 {
		t.Fatalf("expected soft_gold balance 400 after purchase, got %d; wallet=%+v", got, purchaseResp.Wallet)
	}

	var loadoutResp profilePayload
	mustExpectStatus(t, http.MethodPatch, server.URL+"/api/v1/profile/me/loadout", map[string]any{
		"default_character_id":      "10101",
		"default_character_skin_id": "skin_gold",
		"default_bubble_style_id":   "bubble_round",
		"default_bubble_skin_id":    "bubble_skin_gold",
		"title_id":                  "title_rookie",
	}, authHeader, http.StatusOK, &loadoutResp)
	if loadoutResp.TitleID != "title_rookie" {
		t.Fatalf("expected title loadout to update, got %+v", loadoutResp)
	}

	var replayResp purchasePayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.title.rookie",
		"idempotency_key":           "itest-title-rookie",
		"expected_catalog_revision": shopResp.CatalogRevision,
	}, authHeader, http.StatusOK, &replayResp)
	if replayResp.PurchaseID != purchaseResp.PurchaseID || !replayResp.IdempotentReplay {
		t.Fatalf("expected idempotent replay of %s, got %+v", purchaseResp.PurchaseID, replayResp)
	}

	var alreadyOwnedErr errorPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.title.rookie",
		"idempotency_key":           "itest-title-rookie-again",
		"expected_catalog_revision": shopResp.CatalogRevision,
	}, authHeader, http.StatusConflict, &alreadyOwnedErr)
	if alreadyOwnedErr.ErrorCode != purchase.ErrPurchaseAlreadyOwned.Error() {
		t.Fatalf("expected already owned error, got %+v", alreadyOwnedErr)
	}

	var ticketResp ticketPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/tickets/room-entry", map[string]any{
		"purpose":                    "create",
		"room_kind":                  "online_room",
		"selected_character_id":      "10101",
		"selected_character_skin_id": "skin_gold",
		"selected_bubble_style_id":   "bubble_round",
		"selected_bubble_skin_id":    "bubble_skin_gold",
	}, authHeader, http.StatusOK, &ticketResp)
	if ticketResp.TicketID == "" || ticketResp.Ticket == "" {
		t.Fatalf("ticket response missing ticket data: %+v", ticketResp)
	}

	var logoutResp map[string]any
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/logout", map[string]any{
		"refresh_token":     refreshResp.RefreshToken,
		"device_session_id": refreshResp.DeviceSessionID,
	}, authHeader, http.StatusOK, &logoutResp)

	var revokedErr errorPayload
	mustExpectStatus(t, http.MethodGet, server.URL+"/api/v1/profile/me", nil, authHeader, http.StatusUnauthorized, &revokedErr)
	if revokedErr.ErrorCode != auth.ErrSessionRevoked.Error() {
		t.Fatalf("expected revoked error, got %+v", revokedErr)
	}
}

func TestRegisterDuplicateReturnsConflict(t *testing.T) {
	env := newIntegrationEnv(t)
	t.Cleanup(env.cleanup)

	mustResetDatabase(t, env.store.Pool)

	server := httptest.NewServer(env.router)
	defer server.Close()

	account := fmt.Sprintf("dup_%d", time.Now().UnixNano())
	body := map[string]any{
		"account":         account,
		"password":        "12345678",
		"nickname":        account,
		"client_platform": "windows",
	}

	var first authPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/register", body, nil, http.StatusOK, &first)

	var duplicateErr errorPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/auth/register", body, nil, http.StatusConflict, &duplicateErr)
	if duplicateErr.ErrorCode != auth.ErrAccountAlreadyExists.Error() {
		t.Fatalf("expected duplicate account error, got %+v", duplicateErr)
	}
}

func TestPurchaseValidationIntegration(t *testing.T) {
	env := newIntegrationEnv(t)
	t.Cleanup(env.cleanup)

	mustResetDatabase(t, env.store.Pool)

	server := httptest.NewServer(env.router)
	defer server.Close()

	authHeader, shopRevision := registerForPurchaseTest(t, server.URL)

	var revisionErr errorPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.title.rookie",
		"idempotency_key":           "bad-revision",
		"expected_catalog_revision": shopRevision + 1,
	}, authHeader, http.StatusConflict, &revisionErr)
	if revisionErr.ErrorCode != purchase.ErrPurchaseCatalogRevision.Error() {
		t.Fatalf("expected revision mismatch, got %+v", revisionErr)
	}

	var ownedErr errorPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.skin.gold",
		"idempotency_key":           "owned-character",
		"expected_catalog_revision": shopRevision,
	}, authHeader, http.StatusConflict, &ownedErr)
	if ownedErr.ErrorCode != purchase.ErrPurchaseAlreadyOwned.Error() {
		t.Fatalf("expected already owned, got %+v", ownedErr)
	}

	var fundsErr errorPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/shop/purchases", map[string]any{
		"offer_id":                  "offer.title.rookie",
		"idempotency_key":           "no-funds",
		"expected_catalog_revision": shopRevision,
	}, authHeader, http.StatusConflict, &fundsErr)
	if fundsErr.ErrorCode != purchase.ErrPurchaseInsufficientFunds.Error() {
		t.Fatalf("expected insufficient funds, got %+v", fundsErr)
	}

	var loadoutErr errorPayload
	mustExpectStatus(t, http.MethodPatch, server.URL+"/api/v1/profile/me/loadout", map[string]any{
		"default_character_id":      "10101",
		"default_character_skin_id": "skin_gold",
		"default_bubble_style_id":   "bubble_round",
		"default_bubble_skin_id":    "bubble_skin_gold",
		"avatar_id":                 "avatar_missing",
	}, authHeader, http.StatusConflict, &loadoutErr)
	if loadoutErr.ErrorCode != profile.ErrLoadoutNotOwned.Error() {
		t.Fatalf("expected loadout not owned, got %+v", loadoutErr)
	}
}

type integrationEnv struct {
	store  *storage.PostgresStore
	router http.Handler
}

func newIntegrationEnv(t *testing.T) *integrationEnv {
	t.Helper()

	dsn := os.Getenv("ACCOUNT_SERVICE_TEST_POSTGRES_DSN")
	if dsn == "" {
		dsn = defaultTestPostgresDSN
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	store, err := storage.NewPostgresStore(ctx, dsn, false)
	if err != nil {
		t.Skipf("postgres not available for integration tests: %v", err)
	}

	accountRepo := storage.NewAccountRepository(store.Pool)
	profileRepo := storage.NewProfileRepository(store.Pool)
	walletRepo := storage.NewWalletRepository(store.Pool)
	inventoryRepo := storage.NewInventoryRepository(store.Pool)
	sessionRepo := storage.NewSessionRepository(store.Pool)
	ticketRepo := storage.NewTicketRepository(store.Pool)

	passwordHasher := auth.NewPasswordHasher()
	tokenIssuer := auth.NewTokenIssuer("replace_me_access_secret")
	sessionService := auth.NewSessionService(sessionRepo, false)
	authService := auth.NewAuthService(store.Pool, accountRepo, profileRepo, sessionRepo, passwordHasher, tokenIssuer, sessionService, 15*time.Minute, 14*24*time.Hour)
	profileService := profile.NewService(profileRepo)
	walletService := economy.NewWalletService(profileRepo, walletRepo)
	inventoryService := inventory.NewInventoryService(profileRepo, inventoryRepo)
	shopCatalogProvider := shop.NewDefaultCatalogProvider()
	purchaseService := purchase.NewService(store.Pool, shopCatalogProvider, tokenIssuer)
	roomTicketIssuer := ticket.NewRoomTicketIssuer("replace_me_room_ticket_secret")
	roomTicketService := ticket.NewService(profileService, ticketRepo, roomTicketIssuer, nil, 60*time.Second)

	router := NewRouter(RouterDeps{
		AuthService:       authService,
		AuthHandler:       NewAuthHandler(authService),
		ProfileHandler:    NewProfileHandler(profileService),
		WalletHandler:     NewWalletHandler(walletService),
		InventoryHandler:  NewInventoryHandler(inventoryService),
		ShopHandler:       NewShopHandler(shopCatalogProvider),
		PurchaseHandler:   NewPurchaseHandler(purchaseService),
		RoomTicketHandler: NewRoomTicketHandler(roomTicketService),
		ReadinessCheck:    store.Ping,
	})

	return &integrationEnv{
		store:  store,
		router: router,
	}
}

func (e *integrationEnv) cleanup() {
	if e != nil && e.store != nil {
		e.store.Close()
	}
}

func mustResetDatabase(t *testing.T, db storage.DBTX) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if _, err := db.Exec(ctx, `
TRUNCATE TABLE
	purchase_grants,
	purchase_orders,
	wallet_ledger_entries,
	wallet_balances,
	room_entry_tickets,
	account_sessions,
	player_owned_assets,
	player_profiles,
	accounts
CASCADE
`); err != nil {
		t.Fatalf("reset database: %v", err)
	}
}

func seedWalletBalance(t *testing.T, db storage.DBTX, profileID string, currencyID string, balance int64) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	walletRepo := storage.NewWalletRepository(db)
	if _, err := walletRepo.CreditBalance(ctx, profileID, currencyID, balance, time.Now().UTC()); err != nil {
		t.Fatalf("seed wallet balance: %v", err)
	}
	if _, err := walletRepo.BumpProfileWalletRevision(ctx, profileID); err != nil {
		t.Fatalf("seed wallet revision: %v", err)
	}
}

func registerForPurchaseTest(t *testing.T, serverURL string) (map[string]string, int64) {
	t.Helper()
	account := fmt.Sprintf("purchase_%d", time.Now().UnixNano())
	var registerResp authPayload
	mustExpectStatus(t, http.MethodPost, serverURL+"/api/v1/auth/register", map[string]any{
		"account":         account,
		"password":        "12345678",
		"nickname":        account,
		"client_platform": "windows",
	}, nil, http.StatusOK, &registerResp)

	var loginResp authPayload
	mustExpectStatus(t, http.MethodPost, serverURL+"/api/v1/auth/login", map[string]any{
		"account":         account,
		"password":        "12345678",
		"client_platform": "windows",
	}, nil, http.StatusOK, &loginResp)

	authHeader := map[string]string{"Authorization": "Bearer " + loginResp.AccessToken}
	var shopResp shopCatalogPayload
	mustExpectStatus(t, http.MethodGet, serverURL+"/api/v1/shop/catalog", nil, authHeader, http.StatusOK, &shopResp)
	return authHeader, shopResp.CatalogRevision
}

func mustExpectStatus(t *testing.T, method string, url string, body any, headers map[string]string, wantStatus int, out any) {
	t.Helper()

	var reader io.Reader
	if body != nil {
		payload, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal request body: %v", err)
		}
		reader = bytes.NewReader(payload)
	}

	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for key, value := range headers {
		req.Header.Set(key, value)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do request: %v", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read response: %v", err)
	}
	if resp.StatusCode != wantStatus {
		t.Fatalf("%s %s expected status %d, got %d: %s", method, url, wantStatus, resp.StatusCode, string(raw))
	}
	if out != nil {
		if err := json.Unmarshal(raw, out); err != nil {
			t.Fatalf("decode response: %v; raw=%s", err, string(raw))
		}
	}
}

func mustExpectTextContains(t *testing.T, method string, url string, wantStatus int, wantText string) {
	t.Helper()

	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do request: %v", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read response: %v", err)
	}
	if resp.StatusCode != wantStatus {
		t.Fatalf("%s %s expected status %d, got %d: %s", method, url, wantStatus, resp.StatusCode, string(raw))
	}
	if !bytes.Contains(raw, []byte(wantText)) {
		t.Fatalf("%s %s expected body to contain %q, got: %s", method, url, wantText, string(raw))
	}
}

type authPayload struct {
	OK                    bool   `json:"ok"`
	AccountID             string `json:"account_id"`
	ProfileID             string `json:"profile_id"`
	AccessToken           string `json:"access_token"`
	RefreshToken          string `json:"refresh_token"`
	DeviceSessionID       string `json:"device_session_id"`
	AccessExpireAtUnixSec int64  `json:"access_expire_at_unix_sec"`
}

type profilePayload struct {
	OK                    bool     `json:"ok"`
	ProfileID             string   `json:"profile_id"`
	AccountID             string   `json:"account_id"`
	AvatarID              string   `json:"avatar_id"`
	TitleID               string   `json:"title_id"`
	DefaultCharacterID    string   `json:"default_character_id"`
	OwnedCharacterIDs     []string `json:"owned_character_ids"`
	OwnedCharacterSkinIDs []string `json:"owned_character_skin_ids"`
}

type walletPayload struct {
	OK             bool                   `json:"ok"`
	ProfileID      string                 `json:"profile_id"`
	WalletRevision int64                  `json:"wallet_revision"`
	Balances       []walletBalancePayload `json:"balances"`
}

func (p walletPayload) BalanceOf(currencyID string) int64 {
	for _, balance := range p.Balances {
		if balance.CurrencyID == currencyID {
			return balance.Balance
		}
	}
	return 0
}

type walletBalancePayload struct {
	CurrencyID string `json:"currency_id"`
	Balance    int64  `json:"balance"`
	Revision   int64  `json:"revision"`
}

type inventoryPayload struct {
	OK                 bool                    `json:"ok"`
	ProfileID          string                  `json:"profile_id"`
	OwnedAssetRevision int64                   `json:"owned_asset_revision"`
	Assets             []inventoryAssetPayload `json:"assets"`
}

func (p inventoryPayload) HasAsset(assetType string, assetID string) bool {
	for _, asset := range p.Assets {
		if asset.AssetType == assetType && asset.AssetID == assetID {
			return true
		}
	}
	return false
}

type inventoryAssetPayload struct {
	AssetType  string `json:"asset_type"`
	AssetID    string `json:"asset_id"`
	State      string `json:"state"`
	Quantity   int64  `json:"quantity"`
	SourceType string `json:"source_type"`
	Revision   int64  `json:"revision"`
}

type shopCatalogPayload struct {
	OK              bool             `json:"ok"`
	NotModified     bool             `json:"not_modified"`
	CatalogRevision int64            `json:"catalog_revision"`
	Currencies      []map[string]any `json:"currencies"`
	Tabs            []map[string]any `json:"tabs"`
	Goods           []map[string]any `json:"goods"`
	Offers          []map[string]any `json:"offers"`
}

type purchasePayload struct {
	OK                 bool             `json:"ok"`
	PurchaseID         string           `json:"purchase_id"`
	OfferID            string           `json:"offer_id"`
	CatalogRevision    int64            `json:"catalog_revision"`
	Status             string           `json:"status"`
	Wallet             walletPayload    `json:"wallet"`
	Inventory          inventoryPayload `json:"inventory"`
	ProfileVersion     int64            `json:"profile_version"`
	OwnedAssetRevision int64            `json:"owned_asset_revision"`
	WalletRevision     int64            `json:"wallet_revision"`
	IdempotentReplay   bool             `json:"idempotent_replay"`
}

type ticketPayload struct {
	OK       bool   `json:"ok"`
	TicketID string `json:"ticket_id"`
	Ticket   string `json:"ticket"`
}

type errorPayload struct {
	OK        bool   `json:"ok"`
	ErrorCode string `json:"error_code"`
	Message   string `json:"message"`
}
