package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/auth"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/career"
	"qqtang/services/game_service/internal/config"
	"qqtang/services/game_service/internal/finalize"
	"qqtang/services/game_service/internal/httpapi"
	"qqtang/services/game_service/internal/queue"
	"qqtang/services/game_service/internal/rating"
	"qqtang/services/game_service/internal/reward"
	"qqtang/services/game_service/internal/rpcapi"
	"qqtang/services/game_service/internal/storage"
	"qqtang/services/shared/contentmanifest"
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

	queueRepo := storage.NewQueueRepository(store.Pool)
	partyQueueRepo := storage.NewPartyQueueRepository(store.Pool)
	partyQueueMemberRepo := storage.NewPartyQueueMemberRepository(store.Pool)
	assignmentRepo := storage.NewAssignmentRepository(store.Pool)
	battleInstanceRepo := storage.NewBattleInstanceRepository(store.Pool)
	careerRepo := storage.NewCareerRepository(store.Pool)
	ratingRepo := storage.NewRatingRepository(store.Pool)

	jwtAuth := auth.NewJWTAuth(cfg.JWTSharedSecret)
	internalAuth := auth.NewInternalAuth(cfg.InternalAuthKeyID, cfg.InternalSharedSecret, time.Duration(cfg.InternalAuthMaxSkewSec)*time.Second)
	ratingService := rating.NewEloService()
	rewardService := reward.NewService()
	queueService := queue.NewService(queueRepo, assignmentRepo, store.Pool, time.Duration(cfg.QueueHeartbeatTTLSeconds)*time.Second)
	manifestLoader, err := contentmanifest.LoadFromFile(cfg.RoomManifestPath)
	if err != nil {
		log.Fatalf("load room manifest: %v", err)
	}
	queueService.ConfigureContentManifest(manifestLoader)
	queueService.ConfigureDefaults(queue.AssignmentDefaults{
		SeasonID:               cfg.DefaultSeasonID,
		MapID:                  cfg.DefaultMapID,
		DSHost:                 cfg.DefaultDSHost,
		DSPort:                 cfg.DefaultDSPort,
		CaptainDeadlineSeconds: cfg.CaptainDeadlineSeconds,
		CommitDeadlineSeconds:  cfg.CommitDeadlineSeconds,
	})
	queueService.ConfigureRatingRepository(ratingRepo)
	queueService.ConfigurePartyQueueRepositories(partyQueueRepo, partyQueueMemberRepo)
	assignmentService := assignment.NewService(assignmentRepo, time.Duration(cfg.CaptainDeadlineSeconds)*time.Second)
	battleAllocService := battlealloc.NewService(assignmentRepo, battleInstanceRepo, cfg.DSManagerURL, cfg.InternalAuthKeyID, cfg.InternalSharedSecret)
	manualRoomService := battlealloc.NewManualRoomService(store.Pool, assignmentRepo, battleAllocService)
	queueService.ConfigureBattleAllocator(newQueueBattleAllocatorAdapter(battleAllocService))
	careerService := career.NewService(careerRepo, ratingRepo)
	finalizeService := finalize.NewService(store.Pool, ratingService, rewardService)
	roomControlRPC := rpcapi.NewRoomControlService(queueService, manualRoomService, assignmentService)

	grpcServer, grpcListener, err := rpcapi.ListenAndServe(cfg.GRPCListenAddr, roomControlRPC)
	if err != nil {
		log.Fatalf("start grpc server: %v", err)
	}
	log.Printf("game_service grpc listening on %s", grpcListener.Addr().String())

	router := httpapi.NewRouter(httpapi.RouterDeps{
		JWTAuth:                         jwtAuth,
		InternalAuth:                    internalAuth,
		MatchmakingHandler:              httpapi.NewMatchmakingHandler(queueService),
		PartyMatchmakingHandler:         httpapi.NewPartyMatchmakingHandler(queueService),
		CareerHandler:                   httpapi.NewCareerHandler(careerService),
		SettlementHandler:               httpapi.NewSettlementHandler(finalizeService),
		InternalAssignmentHandler:       httpapi.NewInternalAssignmentHandler(assignmentService),
		InternalFinalizeHandler:         httpapi.NewInternalFinalizeHandler(finalizeService),
		InternalBattleManifestHandler:   httpapi.NewInternalBattleManifestHandler(battleAllocService),
		InternalBattleReadyHandler:      httpapi.NewInternalBattleReadyHandler(battleAllocService),
		InternalManualRoomBattleHandler: httpapi.NewInternalManualRoomBattleHandler(manualRoomService),
		ReadinessCheck:                  store.Ping,
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
		grpcServer.GracefulStop()
	}()

	log.Printf("game_service listening on %s", cfg.HTTPListenAddr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("listen: %v", err)
	}
}

// queueBattleAllocatorAdapter bridges queue.BattleAllocator and
// battlealloc.Service, keeping the queue package free of battlealloc imports.
type queueBattleAllocatorAdapter struct {
	inner *battlealloc.Service
}

func newQueueBattleAllocatorAdapter(inner *battlealloc.Service) *queueBattleAllocatorAdapter {
	return &queueBattleAllocatorAdapter{inner: inner}
}

func (a *queueBattleAllocatorAdapter) AllocateBattle(ctx context.Context, input queue.BattleAllocateInput) (queue.BattleAllocateResult, error) {
	result, err := a.inner.AllocateBattle(ctx, battlealloc.AllocateInput{
		AssignmentID:        input.AssignmentID,
		BattleID:            input.BattleID,
		MatchID:             input.MatchID,
		SourceRoomID:        input.SourceRoomID,
		SourceRoomKind:      input.SourceRoomKind,
		ModeID:              input.ModeID,
		RuleSetID:           input.RuleSetID,
		MapID:               input.MapID,
		ExpectedMemberCount: input.ExpectedMemberCount,
		HostHint:            input.HostHint,
	})
	if err != nil {
		return queue.BattleAllocateResult{}, err
	}
	return queue.BattleAllocateResult{
		BattleID:        result.BattleID,
		DSInstanceID:    result.DSInstanceID,
		ServerHost:      result.ServerHost,
		ServerPort:      result.ServerPort,
		AllocationState: result.AllocationState,
	}, nil
}
