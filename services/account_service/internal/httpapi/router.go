package httpapi

import (
	"net/http"

	"qqtang/services/account_service/internal/auth"
)

type RouterDeps struct {
	AuthService       *auth.AuthService
	AuthHandler       *AuthHandler
	ProfileHandler    *ProfileHandler
	RoomTicketHandler *RoomTicketHandler
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /v1/auth/register", deps.AuthHandler.Register)
	mux.HandleFunc("POST /v1/auth/login", deps.AuthHandler.Login)
	mux.HandleFunc("POST /v1/auth/refresh", deps.AuthHandler.Refresh)
	mux.Handle("POST /v1/auth/logout", withAuth(deps.AuthService, http.HandlerFunc(deps.AuthHandler.Logout)))
	mux.Handle("GET /v1/auth/session", withAuth(deps.AuthService, http.HandlerFunc(deps.AuthHandler.Session)))

	mux.Handle("GET /v1/profile/me", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.GetMe)))
	mux.Handle("PATCH /v1/profile/me", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.PatchMe)))
	mux.Handle("PATCH /v1/profile/me/loadout", withAuth(deps.AuthService, http.HandlerFunc(deps.ProfileHandler.PatchLoadout)))

	mux.Handle("POST /v1/room-tickets", withAuth(deps.AuthService, http.HandlerFunc(deps.RoomTicketHandler.Create)))

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	return mux
}
