package main

import (
	"context"
	"errors"
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

	store, err := storage.NewPostgresStore(ctx, cfg.PostgresDSN, cfg.LogSQL)
	if err != nil {
		log.Fatalf("connect postgres: %v", err)
	}
	defer store.Close()

	accountRepo := storage.NewAccountRepository(store.Pool)
	profileRepo := storage.NewProfileRepository(store.Pool)
	sessionRepo := storage.NewSessionRepository(store.Pool)
	ticketRepo := storage.NewTicketRepository(store.Pool)

	passwordHasher := auth.NewPasswordHasher()
	tokenIssuer := auth.NewTokenIssuer(cfg.TokenSignSecret)
	sessionService := auth.NewSessionService(sessionRepo, cfg.AllowMultiDevice)
	authService := auth.NewAuthService(
		store.Pool,
		accountRepo,
		profileRepo,
		sessionRepo,
		passwordHasher,
		tokenIssuer,
		sessionService,
		time.Duration(cfg.AccessTokenTTLSeconds)*time.Second,
		time.Duration(cfg.RefreshTokenTTLSeconds)*time.Second,
	)
	profileService := profile.NewService(profileRepo)
	roomTicketIssuer := ticket.NewRoomTicketIssuer(cfg.RoomTicketSignSecret)
	assignmentGrantClient := ticket.NewAssignmentGrantClient(cfg.GameServiceBaseURL, cfg.GameInternalAuthKeyID, cfg.GameInternalSharedSecret)
	roomTicketService := ticket.NewService(profileService, ticketRepo, roomTicketIssuer, assignmentGrantClient, time.Duration(cfg.RoomTicketTTLSeconds)*time.Second)

	router := httpapi.NewRouter(httpapi.RouterDeps{
		AuthService:       authService,
		AuthHandler:       httpapi.NewAuthHandler(authService),
		ProfileHandler:    httpapi.NewProfileHandler(profileService),
		RoomTicketHandler: httpapi.NewRoomTicketHandler(roomTicketService),
		ReadinessCheck:    store.Ping,
	})

	server := &http.Server{
		Addr:              cfg.HTTPListenAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	log.Printf("account_service listening on %s", cfg.HTTPListenAddr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("listen: %v", err)
	}
}
