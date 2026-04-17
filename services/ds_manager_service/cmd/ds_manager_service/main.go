package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/config"
	"qqtang/services/ds_manager_service/internal/httpapi"
	"qqtang/services/ds_manager_service/internal/process"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadFromEnv()
	if err != nil {
		log.Fatalf("[ds_manager] config error: %v", err)
	}

	alloc := allocator.New(cfg.PortRangeStart, cfg.PortRangeEnd, cfg.DSHost)

	runner := process.NewGodotProcessRunner(process.RunnerConfig{
		GodotExecutable:    cfg.GodotExecutable,
		ProjectRoot:        cfg.ProjectRoot,
		BattleScenePath:    cfg.BattleScenePath,
		BattleTicketSecret: cfg.BattleTicketSecret,
		BattleLogDir:       cfg.BattleLogDir,
	})

	allocateHandler := httpapi.NewAllocateHandler(alloc, runner)
	readyHandler := httpapi.NewReadyHandler(alloc)
	activeHandler := httpapi.NewActiveHandler(alloc)
	reapHandler := httpapi.NewReapHandler(alloc, runner)
	internalAuth := auth.NewInternalAuth(cfg.InternalAuthKeyID, cfg.InternalSharedSecret, time.Duration(cfg.InternalAuthMaxSkewSec)*time.Second)

	router := httpapi.NewRouter(httpapi.RouterDeps{
		Allocator:       alloc,
		ProcessRunner:   runner,
		InternalAuth:    internalAuth,
		AllocateHandler: allocateHandler,
		ReadyHandler:    readyHandler,
		ActiveHandler:   activeHandler,
		ReapHandler:     reapHandler,
	})

	srv := &http.Server{
		Addr:              cfg.HTTPListenAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// Reaper goroutine: periodically clean up stale instances
	go func() {
		readyTimeout := time.Duration(cfg.ReadyTimeoutSec) * time.Second
		idleReapTimeout := time.Duration(cfg.IdleReapTimeoutSec) * time.Second
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				stale := alloc.ListStale(readyTimeout, idleReapTimeout)
				for _, battleID := range stale {
					log.Printf("[ds_manager] reaping stale instance battle_id=%s", battleID)
					if runner.IsRunning(battleID) {
						_ = runner.Kill(battleID)
					}
					alloc.Release(battleID)
				}
			}
		}
	}()

	go func() {
		log.Printf("[ds_manager] listening on %s", cfg.HTTPListenAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[ds_manager] server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("[ds_manager] shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("[ds_manager] shutdown error: %v", err)
	}
}
