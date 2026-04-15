package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"time"

	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/platform/httpx"
	"qqtang/services/game_service/internal/storage"
)

type InternalManualRoomBattleHandler struct {
	service        *battlealloc.Service
	assignmentRepo *storage.AssignmentRepository
}

func NewInternalManualRoomBattleHandler(service *battlealloc.Service, assignmentRepo *storage.AssignmentRepository) *InternalManualRoomBattleHandler {
	return &InternalManualRoomBattleHandler{service: service, assignmentRepo: assignmentRepo}
}

func (h *InternalManualRoomBattleHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SourceRoomID        string `json:"source_room_id"`
		SourceRoomKind      string `json:"source_room_kind"`
		ModeID              string `json:"mode_id"`
		RuleSetID           string `json:"rule_set_id"`
		MapID               string `json:"map_id"`
		ExpectedMemberCount int    `json:"expected_member_count"`
		Members             []struct {
			AccountID      string `json:"account_id"`
			ProfileID      string `json:"profile_id"`
			AssignedTeamID int    `json:"assigned_team_id"`
		} `json:"members"`
		HostHint string `json:"host_hint"`
	}

	if err := httpx.DecodeJSONBody(w, r, &req); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}

	if req.SourceRoomID == "" || req.ModeID == "" || len(req.Members) == 0 {
		httpx.WriteError(w, http.StatusBadRequest, "MISSING_FIELDS", "source_room_id, mode_id, members are required")
		return
	}

	assignmentID, err := opaqueID("assign")
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "ID_GEN_FAILED", err.Error())
		return
	}
	battleID, err := opaqueID("battle")
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "ID_GEN_FAILED", err.Error())
		return
	}
	matchID, err := opaqueID("match")
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "ID_GEN_FAILED", err.Error())
		return
	}

	now := time.Now().UTC()
	expectedMemberCount := req.ExpectedMemberCount
	if expectedMemberCount <= 0 {
		expectedMemberCount = len(req.Members)
	}

	captainAccountID := ""
	if len(req.Members) > 0 {
		captainAccountID = req.Members[0].AccountID
	}

	assignment := storage.Assignment{
		AssignmentID:           assignmentID,
		QueueKey:               "manual_room",
		QueueType:              "manual",
		SeasonID:               "",
		RoomID:                 req.SourceRoomID,
		RoomKind:               req.SourceRoomKind,
		MatchID:                matchID,
		ModeID:                 req.ModeID,
		RuleSetID:              req.RuleSetID,
		MapID:                  req.MapID,
		CaptainAccountID:       captainAccountID,
		AssignmentRevision:     1,
		ExpectedMemberCount:    expectedMemberCount,
		State:                  "assigned",
		CaptainDeadlineUnixSec: now.Add(60 * time.Second).Unix(),
		CommitDeadlineUnixSec:  now.Add(120 * time.Second).Unix(),
		CreatedAt:              now,
		UpdatedAt:              now,
		SourceRoomID:           req.SourceRoomID,
		SourceRoomKind:         req.SourceRoomKind,
		BattleID:               battleID,
		AllocationState:        "assigned",
		RoomReturnPolicy:       "return_to_source_room",
	}
	if err := h.assignmentRepo.Insert(r.Context(), assignment); err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INSERT_FAILED", err.Error())
		return
	}

	for _, m := range req.Members {
		member := storage.AssignmentMember{
			AssignmentID:       assignmentID,
			AccountID:          m.AccountID,
			ProfileID:          m.ProfileID,
			TicketRole:         "join",
			AssignedTeamID:     m.AssignedTeamID,
			JoinState:          "assigned",
			BattleJoinState:    "assigned",
			RoomReturnState:    "pending",
			SourceRoomID:       req.SourceRoomID,
			CreatedAt:          now,
			UpdatedAt:          now,
		}
		if m.AccountID == captainAccountID {
			member.TicketRole = "create"
		}
		if err := h.assignmentRepo.InsertMember(r.Context(), member); err != nil {
			httpx.WriteError(w, http.StatusInternalServerError, "INSERT_MEMBER_FAILED", err.Error())
			return
		}
	}

	result, err := h.service.AllocateBattle(r.Context(), battlealloc.AllocateInput{
		AssignmentID:        assignmentID,
		BattleID:            battleID,
		MatchID:             matchID,
		SourceRoomID:        req.SourceRoomID,
		SourceRoomKind:      req.SourceRoomKind,
		ModeID:              req.ModeID,
		RuleSetID:           req.RuleSetID,
		MapID:               req.MapID,
		ExpectedMemberCount: expectedMemberCount,
		HostHint:            req.HostHint,
	})
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "ALLOCATION_FAILED", err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"assignment_id":    assignmentID,
		"battle_id":        battleID,
		"match_id":         matchID,
		"ds_instance_id":   result.DSInstanceID,
		"allocation_state": result.AllocationState,
		"server_host":      result.ServerHost,
		"server_port":      result.ServerPort,
	})
}

func opaqueID(prefix string) (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("opaqueID: %w", err)
	}
	return prefix + "_" + hex.EncodeToString(buf), nil
}
