package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/config"
	"qqtang/services/room_service/internal/gameclient"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/observability"
	"qqtang/services/room_service/internal/registry"
	"qqtang/services/room_service/internal/roomapp"
	"qqtang/services/room_service/internal/wsapi"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadFromEnv()
	if err != nil {
		fatalf("load config: %v", err)
	}

	logger := observability.NewLogger(cfg.RoomLogLevel)
	manifestLoader, err := manifest.LoadFromFile(cfg.RoomManifestPath)
	if err != nil {
		fatalf("load manifest: %v", err)
	}

	reg := registry.New(cfg.RoomInstanceID, cfg.RoomShardID)
	defer reg.Close()

	gameClient := gameclient.New(cfg.RoomGameServiceGRPCAddr)
	gameClient.ConfigureInternalHTTP(cfg.RoomGameServiceBaseURL, cfg.RoomGameInternalAuthKeyID, cfg.RoomGameInternalAuthSecret)

	app := roomapp.NewService(
		reg,
		manifestLoader,
		auth.NewTicketVerifier(cfg.RoomTicketSecret),
		gameClient,
	)
	app.SetLogger(logger)
	app.SetEmptyBattleCleanupGrace(time.Duration(cfg.RoomEmptyBattleCleanupGraceSeconds) * time.Second)

	wsServer := wsapi.NewServer(cfg.RoomWSAddr, app, logger, wsapi.OriginPolicy{
			AllowedOrigins:      cfg.RoomAllowedOrigins,
			AllowAll:            cfg.RoomAllowAllOrigins,
			MaxFrameBytes:       int64(cfg.RoomWSMaxFrameBytes),
			ReadTimeoutSeconds:  cfg.RoomWSReadTimeoutSeconds,
			PingIntervalSeconds: cfg.RoomWSPingIntervalSeconds,
		})
	if err := wsServer.Start(); err != nil {
		fatalf("start ws server: %v", err)
	}

	healthServer := &http.Server{
		Addr:              cfg.RoomHTTPAddr,
		Handler:           buildHealthMux(manifestLoader, reg, wsServer),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       30 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		logger.Info("room health server listening", "addr", cfg.RoomHTTPAddr)
		if err := healthServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- fmt.Errorf("health server listen: %w", err)
		}
	}()

	select {
	case <-ctx.Done():
		logger.Info("room_service shutdown signal received")
	case err := <-errCh:
		fatalf("server error: %v", err)
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := wsServer.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown ws server failed", "error", err)
	}
	if err := healthServer.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown health server failed", "error", err)
	}
}

func buildHealthMux(manifestLoader *manifest.Loader, reg *registry.Registry, ws *wsapi.Server) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		if manifestLoader == nil || !manifestLoader.Ready() || reg == nil || !reg.Ready() || ws == nil || !ws.Ready() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	return mux
}

func fatalf(format string, args ...any) {
	_, _ = fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
