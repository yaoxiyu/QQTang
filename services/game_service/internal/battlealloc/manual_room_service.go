package battlealloc

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/game_service/internal/storage"
)

var (
	ErrManualRoomInvalidInput     = errors.New("MANUAL_ROOM_INVALID_INPUT")
	ErrManualRoomPersistFailed    = errors.New("MANUAL_ROOM_PERSIST_FAILED")
	ErrManualRoomAllocationFailed = errors.New("MANUAL_ROOM_ALLOCATION_FAILED")
)

type manualRoomTxWriter interface {
	Insert(ctx context.Context, assignment storage.Assignment) error
	InsertMember(ctx context.Context, member storage.AssignmentMember) error
}

type manualRoomRepository interface {
	WithTx(ctx context.Context, fn func(writer manualRoomTxWriter) error) error
	UpdateAllocationState(ctx context.Context, assignmentID string, allocationState string, battleID string, dsInstanceID string, battleServerHost string, battleServerPort int) error
}

type manualRoomAllocator interface {
	AllocateBattle(ctx context.Context, input AllocateInput) (AllocateResult, error)
}

type assignmentTxRepository struct {
	pool *pgxpool.Pool
	repo *storage.AssignmentRepository
}

func newAssignmentTxRepository(pool *pgxpool.Pool, repo *storage.AssignmentRepository) *assignmentTxRepository {
	return &assignmentTxRepository{pool: pool, repo: repo}
}

func (r *assignmentTxRepository) WithTx(ctx context.Context, fn func(writer manualRoomTxWriter) error) error {
	if r.pool == nil {
		return fn(r.repo)
	}
	return storage.WithTx(ctx, r.pool, func(tx pgx.Tx) error {
		return fn(storage.NewAssignmentRepository(tx))
	})
}

func (r *assignmentTxRepository) UpdateAllocationState(ctx context.Context, assignmentID string, allocationState string, battleID string, dsInstanceID string, battleServerHost string, battleServerPort int) error {
	return r.repo.UpdateAllocationState(ctx, assignmentID, allocationState, battleID, dsInstanceID, battleServerHost, battleServerPort)
}

type ManualRoomService struct {
	repo      manualRoomRepository
	allocator manualRoomAllocator
	nowFn     func() time.Time
	idFn      func(prefix string) (string, error)
}

func NewManualRoomService(pool *pgxpool.Pool, assignmentRepo *storage.AssignmentRepository, allocator manualRoomAllocator) *ManualRoomService {
	return &ManualRoomService{
		repo:      newAssignmentTxRepository(pool, assignmentRepo),
		allocator: allocator,
		nowFn:     func() time.Time { return time.Now().UTC() },
		idFn:      opaqueID,
	}
}

func (s *ManualRoomService) Create(ctx context.Context, input ManualRoomBattleInput) (ManualRoomBattleResult, error) {
	if input.SourceRoomID == "" || input.ModeID == "" || len(input.Members) == 0 {
		return ManualRoomBattleResult{}, ErrManualRoomInvalidInput
	}
	assignmentID, err := s.idFn("assign")
	if err != nil {
		return ManualRoomBattleResult{}, fmt.Errorf("%w: generate assignment id: %v", ErrManualRoomPersistFailed, err)
	}
	battleID, err := s.idFn("battle")
	if err != nil {
		return ManualRoomBattleResult{}, fmt.Errorf("%w: generate battle id: %v", ErrManualRoomPersistFailed, err)
	}
	matchID, err := s.idFn("match")
	if err != nil {
		return ManualRoomBattleResult{}, fmt.Errorf("%w: generate match id: %v", ErrManualRoomPersistFailed, err)
	}
	result := ManualRoomBattleResult{
		AssignmentID:    assignmentID,
		BattleID:        battleID,
		MatchID:         matchID,
		AllocationState: "pending_allocate",
	}

	expectedMemberCount := input.ExpectedMemberCount
	if expectedMemberCount <= 0 {
		expectedMemberCount = len(input.Members)
	}

	now := s.nowFn()
	captainAccountID := input.Members[0].AccountID
	assignmentRecord := storage.Assignment{
		AssignmentID:           assignmentID,
		QueueKey:               "manual_room",
		QueueType:              "manual",
		RoomID:                 input.SourceRoomID,
		RoomKind:               input.SourceRoomKind,
		MatchID:                matchID,
		ModeID:                 input.ModeID,
		RuleSetID:              input.RuleSetID,
		MapID:                  input.MapID,
		CaptainAccountID:       captainAccountID,
		AssignmentRevision:     1,
		ExpectedMemberCount:    expectedMemberCount,
		State:                  "assigned",
		CaptainDeadlineUnixSec: now.Add(60 * time.Second).Unix(),
		CommitDeadlineUnixSec:  now.Add(120 * time.Second).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
		SourceRoomID:           input.SourceRoomID,
		SourceRoomKind:         input.SourceRoomKind,
		BattleID:               battleID,
		AllocationState:        "pending_allocate",
		RoomReturnPolicy:       "return_to_source_room",
	}

	if err := s.repo.WithTx(ctx, func(writer manualRoomTxWriter) error {
		if err := writer.Insert(ctx, assignmentRecord); err != nil {
			return err
		}
		for _, memberInput := range input.Members {
			member := storage.AssignmentMember{
				AssignmentID:    assignmentID,
				AccountID:       memberInput.AccountID,
				ProfileID:       memberInput.ProfileID,
				TicketRole:      "join",
				AssignedTeamID:  memberInput.AssignedTeamID,
				CharacterID:     memberInput.CharacterID,
				CharacterSkinID: memberInput.CharacterSkinID,
				BubbleStyleID:   memberInput.BubbleStyleID,
				BubbleSkinID:    memberInput.BubbleSkinID,
				JoinState:       "assigned",
				BattleJoinState: "assigned",
				RoomReturnState: "pending",
				SourceRoomID:    input.SourceRoomID,
				CreatedAt:       now,
				UpdatedAt:       now,
			}
			if memberInput.AccountID == captainAccountID {
				member.TicketRole = "create"
			}
			if err := writer.InsertMember(ctx, member); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		return result, fmt.Errorf("%w: %v", ErrManualRoomPersistFailed, err)
	}

	if s.allocator == nil {
		_ = s.repo.UpdateAllocationState(ctx, assignmentID, "allocation_failed", battleID, "", "", 0)
		return result, fmt.Errorf("%w: allocator is not configured", ErrManualRoomAllocationFailed)
	}
	allocateResult, err := s.allocator.AllocateBattle(ctx, AllocateInput{
		AssignmentID:        assignmentID,
		BattleID:            battleID,
		MatchID:             matchID,
		SourceRoomID:        input.SourceRoomID,
		SourceRoomKind:      input.SourceRoomKind,
		ModeID:              input.ModeID,
		RuleSetID:           input.RuleSetID,
		MapID:               input.MapID,
		ExpectedMemberCount: expectedMemberCount,
		HostHint:            input.HostHint,
	})
	if err != nil {
		_ = s.repo.UpdateAllocationState(ctx, assignmentID, "allocation_failed", battleID, "", "", 0)
		result.AllocationState = "allocation_failed"
		return result, fmt.Errorf("%w: %v", ErrManualRoomAllocationFailed, err)
	}

	result.DSInstanceID = allocateResult.DSInstanceID
	result.ServerHost = allocateResult.ServerHost
	result.ServerPort = allocateResult.ServerPort
	result.AllocationState = allocateResult.AllocationState
	if result.AllocationState == "" {
		result.AllocationState = "starting"
	}
	if err := s.repo.UpdateAllocationState(ctx, assignmentID, result.AllocationState, battleID, result.DSInstanceID, result.ServerHost, result.ServerPort); err != nil {
		return result, fmt.Errorf("%w: update allocation state: %v", ErrManualRoomAllocationFailed, err)
	}
	return result, nil
}

func opaqueID(prefix string) (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("opaqueID: %w", err)
	}
	return prefix + "_" + hex.EncodeToString(buf), nil
}
