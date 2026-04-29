package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"qqtang/services/ds_manager_service/internal/allocator"
	"qqtang/services/ds_manager_service/internal/auth"
	"qqtang/services/ds_manager_service/internal/config"
	"qqtang/services/ds_manager_service/internal/httpapi"
	"qqtang/services/ds_manager_service/internal/process"
	"qqtang/services/ds_manager_service/internal/runtimepool"
	"qqtang/services/ds_manager_service/internal/runtimepool/dockerwarm"
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

	internalAuth := auth.NewInternalAuth(cfg.InternalAuthKeyID, cfg.InternalSharedSecret, time.Duration(cfg.InternalAuthMaxSkewSec)*time.Second)
	var rtPool runtimepool.RuntimePool
	var allocateHandler *httpapi.AllocateHandler
	var readyHandler *httpapi.ReadyHandler
	var activeHandler *httpapi.ActiveHandler
	var reapHandler *httpapi.ReapHandler
	var statusHandler *httpapi.StatusHandler
	switch cfg.PoolMode {
	case "docker_warm_pool":
		containerRuntime, err := dockerwarm.NewDockerEngineRuntime(cfg.DockerSocket)
		if err != nil {
			log.Fatalf("[ds_manager] docker runtime error: %v", err)
		}
		agentClient := dockerwarm.NewHTTPAgentClient(cfg.DSAgentInternalAuthKeyID, cfg.DSAgentInternalAuthSecret)
		rtPool = dockerwarm.NewDockerWarmPool(dockerwarm.PoolConfig{
			WarmPoolConfig: dockerwarm.WarmPoolConfig{
				PoolID:            cfg.PoolID,
				MinReady:          cfg.PoolMinReady,
				MaxSize:           cfg.PoolMaxSize,
				PrefillBatch:      cfg.PoolPrefillBatch,
				DSImage:           cfg.DSImage,
				DSNetwork:         cfg.DSNetwork,
				DSContainerPrefix: cfg.DSContainerPrefix,
				DSAgentPort:       cfg.DSAgentPort,
				DSBattlePort:      cfg.DSBattlePort,
				DSHostPortStart:   cfg.DSHostPortRangeStart,
				DSHostPortEnd:     cfg.DSHostPortRangeEnd,
				ContainerEnv: map[string]string{
					"DS_AGENT_INTERNAL_AUTH_KEY_ID":        cfg.DSAgentInternalAuthKeyID,
					"DS_AGENT_INTERNAL_AUTH_SHARED_SECRET": cfg.DSAgentInternalAuthSecret,
					"DS_BATTLE_PORT":                       strconv.Itoa(cfg.DSBattlePort),
					"DSM_INTERNAL_AUTH_KEY_ID":             cfg.InternalAuthKeyID,
					"DSM_INTERNAL_AUTH_SHARED_SECRET":      cfg.InternalSharedSecret,
					"GAME_INTERNAL_AUTH_KEY_ID":            cfg.InternalAuthKeyID,
					"GAME_INTERNAL_AUTH_SHARED_SECRET":     cfg.InternalSharedSecret,
					"QQT_BATTLE_TICKET_SECRET":             cfg.BattleTicketSecret,
				},
			},
			AdvertiseMode:      cfg.DSAdvertiseMode,
			PublicHost:         cfg.DSPublicHost,
			GameServiceBaseURL: cfg.GameServiceBaseURL,
			DSMBaseURL:         cfg.DSMBaseURL,
			ReadyTimeoutMS:     cfg.AllocateWaitReadyTimeoutMS,
		}, containerRuntime, agentClient, dockerwarm.NewLeaseRegistry())
		allocateHandler = httpapi.NewRuntimePoolAllocateHandler(rtPool)
		readyHandler = httpapi.NewRuntimePoolReadyHandler(rtPool)
		activeHandler = httpapi.NewRuntimePoolActiveHandler(rtPool)
		reapHandler = httpapi.NewRuntimePoolReapHandler(rtPool)
		statusHandler = httpapi.NewStatusHandler(rtPool)
	case "local_process_legacy":
		allocateHandler = httpapi.NewAllocateHandler(alloc, runner)
		readyHandler = httpapi.NewReadyHandler(alloc)
		activeHandler = httpapi.NewActiveHandler(alloc)
		reapHandler = httpapi.NewReapHandler(alloc, runner)
	default:
		log.Fatalf("[ds_manager] unsupported DSM_POOL_MODE=%s", cfg.PoolMode)
	}

	router := httpapi.NewRouter(httpapi.RouterDeps{
		Allocator:       alloc,
		ProcessRunner:   runner,
		InternalAuth:    internalAuth,
		AllocateHandler: allocateHandler,
		ReadyHandler:    readyHandler,
		ActiveHandler:   activeHandler,
		ReapHandler:     reapHandler,
		StatusHandler:   statusHandler,
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
		interval := time.Duration(cfg.PoolReconcileIntervalSec) * time.Second
		if cfg.PoolMode == "local_process_legacy" {
			interval = 10 * time.Second
		}
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if rtPool != nil {
					if err := rtPool.Reconcile(ctx); err != nil {
						log.Printf("[ds_manager] runtime pool reconcile failed: %v", err)
					}
					continue
				}
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
