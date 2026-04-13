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
	"qqtang/services/account_service/internal/profile"
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

	var ticketResp ticketPayload
	mustExpectStatus(t, http.MethodPost, server.URL+"/api/v1/tickets/room-entry", map[string]any{
		"purpose":                    "create",
		"room_kind":                  "online_room",
		"selected_character_id":      "char_huoying",
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
	sessionRepo := storage.NewSessionRepository(store.Pool)
	ticketRepo := storage.NewTicketRepository(store.Pool)

	passwordHasher := auth.NewPasswordHasher()
	tokenIssuer := auth.NewTokenIssuer("replace_me_access_secret")
	sessionService := auth.NewSessionService(sessionRepo, false)
	authService := auth.NewAuthService(store.Pool, accountRepo, profileRepo, sessionRepo, passwordHasher, tokenIssuer, sessionService, 15*time.Minute, 14*24*time.Hour)
	profileService := profile.NewService(profileRepo)
	roomTicketIssuer := ticket.NewRoomTicketIssuer("replace_me_room_ticket_secret")
	roomTicketService := ticket.NewService(profileService, ticketRepo, roomTicketIssuer, 60*time.Second)

	router := NewRouter(RouterDeps{
		AuthService:       authService,
		AuthHandler:       NewAuthHandler(authService),
		ProfileHandler:    NewProfileHandler(profileService),
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
	DefaultCharacterID    string   `json:"default_character_id"`
	OwnedCharacterIDs     []string `json:"owned_character_ids"`
	OwnedCharacterSkinIDs []string `json:"owned_character_skin_ids"`
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
