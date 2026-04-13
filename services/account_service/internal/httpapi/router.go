package httpapi

import (
	"context"
	"net/http"

	"qqtang/services/account_service/internal/auth"
)

type RouterDeps struct {
	AuthService       *auth.AuthService
	AuthHandler       *AuthHandler
	ProfileHandler    *ProfileHandler
	RoomTicketHandler *RoomTicketHandler
	ReadinessCheck    func(ctx context.Context) error
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	registerVersionedRoutes := func(prefix string) {
		mux.HandleFunc("POST "+prefix+"/auth/register", deps.AuthHandler.Register)
		mux.HandleFunc("POST "+prefix+"/auth/login", deps.AuthHandler.Login)
		mux.HandleFunc("POST "+prefix+"/auth/refresh", deps.AuthHandler.Refresh)
		mux.Handle("POST "+prefix+"/auth/logout", withAuth(deps.AuthService, http.HandlerFunc(deps.AuthHandler.Logout)))
		mux.Handle("GET "+prefix+"/auth/session", withAuth(deps.AuthService, http.HandlerFunc(deps.AuthHandler.Session)))

		mux.Handle("GET "+prefix+"/profile/me", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.GetMe)))
		mux.Handle("PATCH "+prefix+"/profile/me", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.PatchMe)))
		mux.Handle("PATCH "+prefix+"/profile/me/loadout", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.PatchLoadout)))
	}

	registerVersionedRoutes("/api/v1")
	registerVersionedRoutes("/v1")
	mux.Handle("POST /api/v1/tickets/room-entry", withAuth(deps.AuthService, http.HandlerFunc(deps.RoomTicketHandler.Create)))
	mux.Handle("POST /v1/room-tickets", withAuth(deps.AuthService, http.HandlerFunc(deps.RoomTicketHandler.Create)))

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if deps.ReadinessCheck == nil {
			writeError(w, http.StatusServiceUnavailable, "READINESS_CHECK_MISSING", "Readiness check is not configured")
			return
		}
		if err := deps.ReadinessCheck(r.Context()); err != nil {
			writeError(w, http.StatusServiceUnavailable, "DB_NOT_READY", "Database is not ready")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	return mux
}
