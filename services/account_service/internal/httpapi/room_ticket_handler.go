package httpapi

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"

	"qqtang/services/account_service/internal/ticket"
)

type RoomTicketHandler struct {
	ticketService *ticket.Service
}

func NewRoomTicketHandler(ticketService *ticket.Service) *RoomTicketHandler {
	return &RoomTicketHandler{ticketService: ticketService}
}

func (h *RoomTicketHandler) Create(w http.ResponseWriter, r *http.Request) {
	authResult := getAuthResult(r.Context())
	var request ticket.CreateTicketInput
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}
	request.AccountID = authResult.AccountID
	request.DeviceSessionID = authResult.DeviceSessionID
	result, err := h.ticketService.CreateTicket(r.Context(), request)
	if err != nil {
		status, code := mapTicketError(err)
		writeError(w, status, code, code)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                         true,
		"ticket":                     result.Ticket,
		"ticket_id":                  result.TicketID,
		"account_id":                 result.AccountID,
		"profile_id":                 result.ProfileID,
		"device_session_id":          result.DeviceSessionID,
		"purpose":                    result.Purpose,
		"room_id":                    result.RoomID,
		"room_kind":                  result.RoomKind,
		"requested_match_id":         result.RequestedMatchID,
		"assignment_id":              result.AssignmentID,
		"match_source":               result.MatchSource,
		"season_id":                  result.SeasonID,
		"locked_map_id":              result.LockedMapID,
		"locked_rule_set_id":         result.LockedRuleSetID,
		"locked_mode_id":             result.LockedModeID,
		"assigned_team_id":           result.AssignedTeamID,
		"expected_member_count":      result.ExpectedMemberCount,
		"auto_ready_on_join":         result.AutoReadyOnJoin,
		"hidden_room":                result.HiddenRoom,
		"display_name":               result.DisplayName,
		"allowed_character_ids":      result.AllowedCharacterIDs,
		"allowed_character_skin_ids": result.AllowedCharacterSkinIDs,
		"allowed_bubble_style_ids":   result.AllowedBubbleStyleIDs,
		"allowed_bubble_skin_ids":    result.AllowedBubbleSkinIDs,
		"issued_at_unix_sec":         result.IssuedAtUnixSec,
		"expire_at_unix_sec":         result.ExpireAtUnixSec,
	})
}

func mapTicketError(err error) (int, string) {
	switch {
	case errors.Is(err, ticket.ErrPurposeInvalid), errors.Is(err, ticket.ErrTargetInvalid), errors.Is(err, ticket.ErrRequestedMatchInvalid), errors.Is(err, ticket.ErrMatchmadeAssignmentRequired):
		return http.StatusBadRequest, err.Error()
	case errors.Is(err, ticket.ErrLoadoutNotOwned), errors.Is(err, ticket.ErrAssignmentGrantFailed), errors.Is(err, ticket.ErrAssignmentGrantForbidden):
		return http.StatusConflict, err.Error()
	default:
		log.Printf("httpapi room ticket internal error: %v", err)
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
