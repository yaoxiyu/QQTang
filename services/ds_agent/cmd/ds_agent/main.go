package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"qqtang/services/ds_agent/internal/auth"
	"qqtang/services/ds_agent/internal/config"
	"qqtang/services/ds_agent/internal/httpapi"
	"qqtang/services/ds_agent/internal/runtime"
	"qqtang/services/ds_agent/internal/state"
)

const version = "dev"

func main() {
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()
	if *showVersion {
		fmt.Println(version)
		return
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadFromEnv()
	if err != nil {
		log.Fatalf("[ds_agent] config error: %v", err)
	}

	internalAuth := auth.NewInternalAuth(cfg.InternalAuthKeyID, cfg.InternalSharedSecret, time.Duration(cfg.InternalAuthMaxSkewSec)*time.Second)
	runner := runtime.NewGodotRunner(runtime.GodotRunnerConfig{
		GodotExecutable: cfg.GodotExecutable,
		ProjectRoot:     cfg.ProjectRoot,
		BattleScenePath: cfg.BattleScenePath,
	})
	router := httpapi.NewRouter(httpapi.RouterDeps{
		InternalAuth: internalAuth,
		StateStore:   state.NewStore(cfg.BattlePort),
		Runner:       runner,
	})

	srv := &http.Server{
		Addr:              cfg.HTTPListenAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("[ds_agent] listening on %s", cfg.HTTPListenAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("[ds_agent] server error: %v", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	log.Println("[ds_agent] shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("[ds_agent] shutdown error: %v", err)
	}
}
