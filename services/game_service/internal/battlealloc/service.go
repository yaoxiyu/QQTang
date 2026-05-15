package battlealloc

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"qqtang/services/game_service/internal/storage"
	"qqtang/services/shared/internalauth"
)

var (
	ErrBattleAlreadyExists  = errors.New("BATTLE_ALREADY_EXISTS")
	ErrBattleNotFound       = errors.New("BATTLE_NOT_FOUND")
	ErrAllocationFailed     = errors.New("BATTLE_ALLOCATION_FAILED")
	ErrManifestStateInvalid = errors.New("ASSIGNMENT_STATE_INVALID")
)

type Service struct {
	assignmentRepo     *storage.AssignmentRepository
	battleInstanceRepo *storage.BattleInstanceRepository
	dsManagerURL       string
	internalAuthKeyID  string
	internalSecret     string
	httpClient         *http.Client
}

func NewService(assignmentRepo *storage.AssignmentRepository, battleInstanceRepo *storage.BattleInstanceRepository, dsManagerURL string, internalAuthKeyID string, internalSecret string, httpTimeout time.Duration) *Service {
	if httpTimeout <= 0 {
		httpTimeout = 45 * time.Second
	}
	return &Service{
		assignmentRepo:     assignmentRepo,
		battleInstanceRepo: battleInstanceRepo,
		dsManagerURL:       dsManagerURL,
		internalAuthKeyID:  internalAuthKeyID,
		internalSecret:     internalSecret,
		httpClient: &http.Client{
			Timeout: httpTimeout,
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
	allocationState := normalizeDSMAllocationState(dsResult.AllocationState)
	battleInstanceState := battleInstanceStateFromAllocation(allocationState)
	if err := s.battleInstanceRepo.UpdateState(ctx, input.BattleID, battleInstanceState); err != nil {
		return AllocateResult{}, err
	}
	if err := s.assignmentRepo.UpdateAllocationState(ctx, input.AssignmentID, allocationState, input.BattleID, dsResult.DSInstanceID, dsResult.ServerHost, dsResult.ServerPort); err != nil {
		return AllocateResult{}, err
	}

	return AllocateResult{
		BattleID:        input.BattleID,
		DSInstanceID:    dsResult.DSInstanceID,
		ServerHost:      dsResult.ServerHost,
		ServerPort:      dsResult.ServerPort,
		AllocationState: allocationState,
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

	if bi.ServerHost == "" || bi.ServerPort <= 0 {
		dsResult, statusErr := s.requestDSBattleStatus(ctx, battleID)
		if statusErr != nil {
			return statusErr
		}
		if dsResult.ServerHost != "" && dsResult.ServerPort > 0 {
			bi.DSInstanceID = dsResult.DSInstanceID
			bi.ServerHost = dsResult.ServerHost
			bi.ServerPort = dsResult.ServerPort
			if err := s.battleInstanceRepo.UpdateDSInfo(ctx, battleID, bi.DSInstanceID, bi.ServerHost, bi.ServerPort); err != nil {
				return err
			}
		}
	}

	if err := s.battleInstanceRepo.UpdateState(ctx, battleID, "ready"); err != nil {
		return err
	}

	return s.assignmentRepo.UpdateAllocationState(ctx, bi.AssignmentID, "battle_ready", battleID, bi.DSInstanceID, bi.ServerHost, bi.ServerPort)
}

func (s *Service) ReapBattle(ctx context.Context, battleID string) error {
	if battleID == "" {
		return fmt.Errorf("battle_id is required")
	}
	if _, err := s.battleInstanceRepo.FindByBattleID(ctx, battleID); err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return ErrBattleNotFound
		}
		return err
	}
	if err := s.requestDSReap(ctx, battleID); err != nil {
		return err
	}
	return s.battleInstanceRepo.UpdateState(ctx, battleID, "reaped")
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
	if assignment.AllocationState == "alloc_failed" || assignment.AllocationState == "allocation_failed" {
		return BattleManifest{}, ErrManifestStateInvalid
	}

	members, err := s.assignmentRepo.ListMembers(ctx, bi.AssignmentID)
	if err != nil {
		return BattleManifest{}, err
	}

	manifest := BattleManifest{
		AssignmentID:        bi.AssignmentID,
		BattleID:            bi.BattleID,
		MatchID:             bi.MatchID,
		SourceRoomID:        assignment.RoomID,
		SourceRoomKind:      assignment.RoomKind,
		SeasonID:            assignment.SeasonID,
		MapID:               assignment.MapID,
		RuleSetID:           assignment.RuleSetID,
		ModeID:              assignment.ModeID,
		ExpectedMemberCount: assignment.ExpectedMemberCount,
	}
	for _, m := range members {
		manifest.Members = append(manifest.Members, ManifestMember{
			AccountID:       m.AccountID,
			ProfileID:       m.ProfileID,
			AssignedTeamID:  m.AssignedTeamID,
			CharacterID:     m.CharacterID,
			CharacterSkinID: m.CharacterSkinID,
			BubbleStyleID:   m.BubbleStyleID,
			BubbleSkinID:    m.BubbleSkinID,
		})
	}
	return manifest, nil
}

type dsAllocateResponse struct {
	OK              bool   `json:"ok"`
	DSInstanceID    string `json:"ds_instance_id"`
	LeaseID         string `json:"lease_id"`
	AllocationState string `json:"allocation_state"`
	ServerHost      string `json:"server_host"`
	ServerPort      int    `json:"server_port"`
	ErrorCode       string `json:"error_code"`
	Message         string `json:"message"`
}

func (s *Service) requestDSAllocation(ctx context.Context, input AllocateInput) (dsAllocateResponse, error) {
	startedAt := time.Now()
	body, err := json.Marshal(map[string]any{
		"battle_id":             input.BattleID,
		"assignment_id":         input.AssignmentID,
		"match_id":              input.MatchID,
		"source_room_id":        input.SourceRoomID,
		"host_hint":             input.HostHint,
		"expected_member_count": input.ExpectedMemberCount,
		"wait_ready":            input.WaitReady,
		"idempotency_key":       input.AssignmentID + ":" + input.BattleID,
	})
	if err != nil {
		return dsAllocateResponse{}, err
	}

	url := s.dsManagerURL + "/internal/v1/battles/allocate"
	log.Printf(
		"[battle_alloc] ds allocate request battle_id=%s assignment_id=%s match_id=%s wait_ready=%t expected_member_count=%d url=%s",
		input.BattleID,
		input.AssignmentID,
		input.MatchID,
		input.WaitReady,
		input.ExpectedMemberCount,
		url,
	)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return dsAllocateResponse{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	if err := internalauth.SignRequest(req, s.internalAuthKeyID, s.internalSecret, body, time.Now().UTC()); err != nil {
		return dsAllocateResponse{}, fmt.Errorf("sign ds_manager request failed: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		log.Printf(
			"[battle_alloc] ds allocate transport error battle_id=%s assignment_id=%s elapsed_ms=%d err=%v",
			input.BattleID,
			input.AssignmentID,
			time.Since(startedAt).Milliseconds(),
			err,
		)
		return dsAllocateResponse{}, fmt.Errorf("ds_manager request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		log.Printf(
			"[battle_alloc] ds allocate read error battle_id=%s assignment_id=%s status=%d elapsed_ms=%d err=%v",
			input.BattleID,
			input.AssignmentID,
			resp.StatusCode,
			time.Since(startedAt).Milliseconds(),
			err,
		)
		return dsAllocateResponse{}, fmt.Errorf("ds_manager response read failed: %w", err)
	}

	var result dsAllocateResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		log.Printf(
			"[battle_alloc] ds allocate parse error battle_id=%s assignment_id=%s status=%d elapsed_ms=%d body=%s err=%v",
			input.BattleID,
			input.AssignmentID,
			resp.StatusCode,
			time.Since(startedAt).Milliseconds(),
			string(respBody),
			err,
		)
		return dsAllocateResponse{}, fmt.Errorf("ds_manager response parse failed: %w", err)
	}

	if resp.StatusCode != http.StatusOK || !result.OK {
		log.Printf(
			"[battle_alloc] ds allocate rejected battle_id=%s assignment_id=%s status=%d elapsed_ms=%d error_code=%s message=%s body=%s",
			input.BattleID,
			input.AssignmentID,
			resp.StatusCode,
			time.Since(startedAt).Milliseconds(),
			result.ErrorCode,
			result.Message,
			string(respBody),
		)
		return dsAllocateResponse{}, fmt.Errorf("ds_manager allocation rejected: %s %s", result.ErrorCode, result.Message)
	}

	log.Printf(
		"[battle_alloc] ds allocate success battle_id=%s assignment_id=%s status=%d elapsed_ms=%d ds_instance_id=%s server_host=%s server_port=%d allocation_state=%s",
		input.BattleID,
		input.AssignmentID,
		resp.StatusCode,
		time.Since(startedAt).Milliseconds(),
		result.DSInstanceID,
		result.ServerHost,
		result.ServerPort,
		result.AllocationState,
	)

	return result, nil
}

func (s *Service) requestDSBattleStatus(ctx context.Context, battleID string) (dsAllocateResponse, error) {
	if s.dsManagerURL == "" {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager url is not configured")
	}
	url := s.dsManagerURL + "/internal/v1/battles/" + battleID
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return dsAllocateResponse{}, err
	}
	if err := internalauth.SignRequest(req, s.internalAuthKeyID, s.internalSecret, nil, time.Now().UTC()); err != nil {
		return dsAllocateResponse{}, fmt.Errorf("sign ds_manager status request failed: %w", err)
	}
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager status request failed: %w", err)
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager status response read failed: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager status rejected status=%d body=%s", resp.StatusCode, string(respBody))
	}
	var result dsAllocateResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager status response parse failed: %w", err)
	}
	if !result.OK {
		return dsAllocateResponse{}, fmt.Errorf("ds_manager status rejected: %s %s", result.ErrorCode, result.Message)
	}
	return result, nil
}

func (s *Service) requestDSReap(ctx context.Context, battleID string) error {
	url := s.dsManagerURL + "/internal/v1/battles/" + battleID + "/reap"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(nil))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if err := internalauth.SignRequest(req, s.internalAuthKeyID, s.internalSecret, nil, time.Now().UTC()); err != nil {
		return fmt.Errorf("sign ds_manager reap request failed: %w", err)
	}
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("ds_manager reap request failed: %w", err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("ds_manager reap rejected status=%d body=%s", resp.StatusCode, string(respBody))
	}
	return nil
}

func normalizeDSMAllocationState(state string) string {
	switch state {
	case "ready", "bound_ready", "battle_ready":
		return "battle_ready"
	case "allocating", "assigning", "starting", "":
		return "allocating"
	case "allocation_failed", "alloc_failed", "failed":
		return "allocation_failed"
	case "active":
		return "active"
	default:
		return state
	}
}

func battleInstanceStateFromAllocation(state string) string {
	switch state {
	case "battle_ready":
		return "ready"
	case "allocation_failed":
		return "allocation_failed"
	case "active":
		return "active"
	default:
		return "allocating"
	}
}
