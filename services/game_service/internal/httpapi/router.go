package httpapi

import (
	"context"
	"net/http"
	"strings"

	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/platform/httpx"
)

type RouterDeps struct {
	JWTAuth                   *auth.JWTAuth
	InternalAuth              *auth.InternalAuth
	MatchmakingHandler        *MatchmakingHandler
	CareerHandler             *CareerHandler
	SettlementHandler         *SettlementHandler
	InternalAssignmentHandler *InternalAssignmentHandler
	InternalFinalizeHandler   *InternalFinalizeHandler
	ReadinessCheck            func(ctx context.Context) error
}

func NewRouter(deps RouterDeps) http.Handler {
	mux := http.NewServeMux()

	mux.Handle("POST /api/v1/matchmaking/queue/enter", withAuth(deps.JWTAuth, http.HandlerFunc(deps.MatchmakingHandler.EnterQueue)))
	mux.Handle("POST /api/v1/matchmaking/queue/cancel", withAuth(deps.JWTAuth, http.HandlerFunc(deps.MatchmakingHandler.CancelQueue)))
	mux.Handle("GET /api/v1/matchmaking/queue/status", withAuth(deps.JWTAuth, http.HandlerFunc(deps.MatchmakingHandler.GetStatus)))
	mux.Handle("GET /api/v1/career/me", withAuth(deps.JWTAuth, http.HandlerFunc(deps.CareerHandler.GetMe)))
	mux.Handle("GET /api/v1/settlement/matches/", withAuth(deps.JWTAuth, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/api/v1/settlement/matches/") {
			http.NotFound(w, r)
			return
		}
		deps.SettlementHandler.GetMatchSummary(w, r)
	})))

	mux.Handle("GET /internal/v1/assignments/", withInternalAuth(deps.InternalAuth, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/grant") {
			http.NotFound(w, r)
			return
		}
		deps.InternalAssignmentHandler.GetGrant(w, r)
	})))
	mux.Handle("POST /internal/v1/assignments/", withInternalAuth(deps.InternalAuth, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/commit") {
			http.NotFound(w, r)
			return
		}
		deps.InternalAssignmentHandler.Commit(w, r)
	})))
	mux.Handle("POST /internal/v1/matches/finalize", withInternalAuth(deps.InternalAuth, http.HandlerFunc(deps.InternalFinalizeHandler.Finalize)))

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if deps.ReadinessCheck == nil {
			httpx.WriteError(w, http.StatusServiceUnavailable, "READINESS_CHECK_MISSING", "Readiness check is not configured")
			return
		}
		if err := deps.ReadinessCheck(r.Context()); err != nil {
			httpx.WriteError(w, http.StatusServiceUnavailable, "DB_NOT_READY", "Database is not ready")
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	return mux
}
