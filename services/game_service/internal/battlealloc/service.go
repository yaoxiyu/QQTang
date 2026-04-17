package battlealloc

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"qqtang/services/game_service/internal/internalhttp"
	"qqtang/services/game_service/internal/storage"
)

var (
	ErrBattleAlreadyExists = errors.New("BATTLE_ALREADY_EXISTS")
	ErrBattleNotFound      = errors.New("BATTLE_NOT_FOUND")
	ErrAllocationFailed    = errors.New("BATTLE_ALLOCATION_FAILED")
)

type Service struct {
	assignmentRepo     *storage.AssignmentRepository
	battleInstanceRepo *storage.BattleInstanceRepository
	dsManagerURL       string
	internalAuthKeyID  string
	internalSecret     string
	httpClient         *http.Client
}

func NewService(assignmentRepo *storage.AssignmentRepository, battleInstanceRepo *storage.BattleInstanceRepository, dsManagerURL string, internalAuthKeyID string, internalSecret string) *Service {
	return &Service{
		assignmentRepo:     assignmentRepo,
		battleInstanceRepo: battleInstanceRepo,
		dsManagerURL:       dsManagerURL,
		internalAuthKeyID:  internalAuthKeyID,
		internalSecret:     internalSecret,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

func (s *Service) AllocateBattle(ctx context.Context, input AllocateInput) (AllocateResult, error) {
	if input.BattleID == "" || input.AssignmentID == "" || input.MatchID == "" {
		return AllocateResult{}, fmt.Errorf("battle_id, assignment_id, match_id are required")
	}

	now := time.Now().UTC()
	bi := storage.BattleInstance{
		BattleID:     input.BattleID,
		AssignmentID: input.AssignmentID,
		MatchID:      input.MatchID,
		State:        "allocating",
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := s.battleInstanceRepo.Insert(ctx, bi); err != nil {
		if storage.IsConstraintViolation(err, "battle_instances_pkey") {
			return AllocateResult{}, ErrBattleAlreadyExists
		}
		return AllocateResult{}, err
	}

	if err := s.assignmentRepo.UpdateAllocationState(ctx, input.AssignmentID, "allocating", input.BattleID, "", "", 0); err != nil {
		return AllocateResult{}, err
	}

	dsResult, err := s.requestDSAllocation(ctx, input)
	if err != nil {
		_ = s.battleInstanceRepo.UpdateState(ctx, input.BattleID, "allocation_failed")
		_ = s.assignmentRepo.UpdateAllocationState(ctx, input.AssignmentID, "allocation_failed", input.BattleID, "", "", 0)
		return AllocateResult{}, fmt.Errorf("%w: %v", ErrAllocationFailed, err)
	}

	if err := s.battleInstanceRepo.UpdateDSInfo(ctx, input.BattleID, dsResult.DSInstanceID, dsResult.ServerHost, dsResult.ServerPort); err != nil {
		return AllocateResult{}, err
	}
	if err := s.battleInstanceRepo.UpdateState(ctx, input.BattleID, "starting"); err != nil {
		return AllocateResult{}, err
	}
	if err := s.assignmentRepo.UpdateAllocationState(ctx, input.AssignmentID, "starting", input.BattleID, dsResult.DSInstanceID, dsResult.ServerHost, dsResult.ServerPort); err != nil {
		return AllocateResult{}, err
	}

	return AllocateResult{
		BattleID:        input.BattleID,
		DSInstanceID:    dsResult.DSInstanceID,
		ServerHost:      dsResult.ServerHost,
		ServerPort:      dsResult.ServerPort,
		AllocationState: "starting",
	}, nil
}

func (s *Service) MarkBattleReady(ctx context.Context, battleID string) error {
	bi, err := s.battleInstanceRepo.FindByBattleID(ctx, battleID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ErrBattleNotFound
		}
		return err
	}

	if err := s.battleInstanceRepo.UpdateState(ctx, battleID, "ready"); err != nil {
		return err
	}

	return s.assignmentRepo.UpdateAllocationState(ctx, bi.AssignmentID, "battle_ready", battleID, bi.DSInstanceID, bi.ServerHost, bi.ServerPort)
}

func (s *Service) GetManifest(ctx context.Context, battleID string) (BattleManifest, error) {
	bi, err := s.battleInstanceRepo.FindByBattleID(ctx, battleID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return BattleManifest{}, ErrBattleNotFound
		}
		return BattleManifest{}, err
	}

	assignment, err := s.assignmentRepo.FindByID(ctx, bi.AssignmentID)
	if err != nil {
		return BattleManifest{}, err
	}

	members, err := s.assignmentRepo.ListMembers(ctx, bi.AssignmentID)
	if err != nil {
		return BattleManifest{}, err
	}

	manifest := BattleManifest{
		AssignmentID:        bi.AssignmentID,
		BattleID:            bi.BattleID,
		MatchID:             bi.MatchID,
		MapID:               assignment.MapID,
		RuleSetID:           assignment.RuleSetID,
		ModeID:              assignment.ModeID,
		ExpectedMemberCount: assignment.ExpectedMemberCount,
	}
	for _, m := range members {
		manifest.Members = append(manifest.Members, ManifestMember{
			AccountID:      m.AccountID,
			ProfileID:      m.ProfileID,
			AssignedTeamID: m.AssignedTeamID,
		})
	}
	return manifest, nil
}

type dsAllocateResponse struct {
	OK           bool   `json:"ok"`
	DSInstanceID string `json:"ds_instance_id"`
	ServerHost   string `json:"server_host"`
	ServerPort   int    `json:"server_port"`
	ErrorCode    string `json:"error_code"`
	Message      string `json:"message"`
}

func (s *Service) requestDSAllocation(ctx context.Context, input AllocateInput) (dsAllocateResponse, error) {
	body, err := json.Marshal(map[string]any{
		"battle_id":             input.BattleID,
		"assignment_id":         input.AssignmentID,
		"match_id":              input.MatchID,
		"host_hint":             input.HostHint,
		"expected_member_count": input.ExpectedMemberCount,
	})
	if err != nil {
		return dsAllocateResponse{}, err
	}

	url := s.dsManagerURL + "/internal/v1/battles/allocate"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return dsAllocateResponse{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	if err := internalhttp.SignRequest(req, s.internalAuthKeyID, s.internalSecret, body, time.Now().UTC()); err != nil {
		return dsAllocateResponse{}, fmt.Errorf("sign ds_manager request failed: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager response read failed: %w", err)
	}

	var result dsAllocateResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager response parse failed: %w", err)
	}

	if resp.StatusCode != http.StatusOK || !result.OK {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager allocation rejected: %s %s", result.ErrorCode, result.Message)
	}

	return result, nil
}
