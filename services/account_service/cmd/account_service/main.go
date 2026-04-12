package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"qqtang/services/account_service/internal/auth"
	"qqtang/services/account_service/internal/config"
	"qqtang/services/account_service/internal/httpapi"
	"qqtang/services/account_service/internal/profile"
	"qqtang/services/account_service/internal/storage"
	"qqtang/services/account_service/internal/ticket"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadFromEnv()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	store, err := storage.NewPostgresStore(ctx, cfg.PostgresDSN)
	if err != nil {
		log.Fatalf("connect postgres: %v", err)
	}
	defer func() {
		_ = store.Close()
	}()

	accountRepo := storage.NewAccountRepository(store.DB)
	profileRepo := storage.NewProfileRepository(store.DB)
	sessionRepo := storage.NewSessionRepository(store.DB)
	ticketRepo := storage.NewTicketRepository(store.DB)

	passwordHasher := auth.NewPasswordHasher()
	tokenIssuer := auth.NewTokenIssuer(cfg.TokenSecret)
	sessionService := auth.NewSessionService(sessionRepo, false)
	authService := auth.NewAuthService(accountRepo, profileRepo, sessionRepo, passwordHasher, tokenIssuer, sessionService, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	profileService := profile.NewService(profileRepo)
	roomTicketIssuer := ticket.NewRoomTicketIssuer(cfg.RoomTicketSecret)
	roomTicketService := ticket.NewService(profileService, ticketRepo, roomTicketIssuer, cfg.RoomTicketTTL)

	router := httpapi.NewRouter(httpapi.RouterDeps{
		AuthService:       authService,
		AuthHandler:       httpapi.NewAuthHandler(authService),
		ProfileHandler:    httpapi.NewProfileHandler(profileService),
		RoomTicketHandler: httpapi.NewRoomTicketHandler(roomTicketService),
	})

	server := &http.Server{
		Addr:              cfg.HTTPListenAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	log.Printf("account_service listening on %s", cfg.HTTPListenAddr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("listen: %v", err)
	}
}
