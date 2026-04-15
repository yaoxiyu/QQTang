package httpapi

import (
	"errors"
	"log"
	"net/http"

	"qqtang/services/account_service/internal/platform/httpx"
	"qqtang/services/account_service/internal/ticket"
)

type BattleTicketHandler struct {
	battleTicketService *ticket.BattleTicketService
}

func NewBattleTicketHandler(battleTicketService *ticket.BattleTicketService) *BattleTicketHandler {
	return &BattleTicketHandler{battleTicketService: battleTicketService}
}

func (h *BattleTicketHandler) Create(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	var request ticket.CreateBattleTicketInput
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	request.AccountID = authResult.AccountID
	request.DeviceSessionID = authResult.DeviceSessionID

	result, err := h.battleTicketService.CreateBattleTicket(r.Context(), request)
	if err != nil {
		status, code := mapBattleTicketError(err)
		httpx.WriteError(w, status, code, code)
		return
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                    true,
		"ticket":                result.Ticket,
		"ticket_id":             result.TicketID,
		"account_id":            result.AccountID,
		"profile_id":            result.ProfileID,
		"device_session_id":     result.DeviceSessionID,
		"assignment_id":         result.AssignmentID,
		"battle_id":             result.BattleID,
		"match_id":              result.MatchID,
		"map_id":                result.MapID,
		"rule_set_id":           result.RuleSetID,
		"mode_id":               result.ModeID,
		"assigned_team_id":      result.AssignedTeamID,
		"expected_member_count": result.ExpectedMemberCount,
		"battle_server_host":    result.BattleServerHost,
		"battle_server_port":    result.BattleServerPort,
		"issued_at_unix_sec":    result.IssuedAtUnixSec,
		"expire_at_unix_sec":    result.ExpireAtUnixSec,
	})
}

func mapBattleTicketError(err error) (int, string) {
	switch {
	case errors.Is(err, ticket.ErrBattleTicketMissingFields):
		return http.StatusBadRequest, err.Error()
	case errors.Is(err, ticket.ErrBattleTicketGrantFailed),
		errors.Is(err, ticket.ErrBattleAssignmentGrantFailed):
		return http.StatusBadGateway, err.Error()
	case errors.Is(err, ticket.ErrBattleAssignmentGrantForbidden):
		return http.StatusForbidden, err.Error()
	default:
		log.Printf("httpapi battle ticket internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
