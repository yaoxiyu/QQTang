package httpapi

import (
	"net/http"

	"qqtang/services/game_service/internal/platform/httpx"
	"qqtang/services/game_service/internal/queue"
)

type MatchmakingHandler struct {
	service *queue.Service
}

func NewMatchmakingHandler(service *queue.Service) *MatchmakingHandler {
	return &MatchmakingHandler{service: service}
}

func (h *MatchmakingHandler) EnterQueue(w http.ResponseWriter, r *http.Request) {
	var request struct {
		QueueType          string   `json:"queue_type"`
		MatchFormatID      string   `json:"match_format_id"`
		ModeID             string   `json:"mode_id"`
		RuleSetID          string   `json:"rule_set_id"`
		PreferredMapPoolID string   `json:"preferred_map_pool_id"`
		SelectedMapIDs     []string `json:"selected_map_ids"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	claims := getAuthClaims(r.Context())
	status, err := h.service.EnterQueue(r.Context(), queue.EnterQueueInput{
		AccountID:          claims.AccountID,
		ProfileID:          claims.ProfileID,
		DeviceSessionID:    claims.DeviceSessionID,
		QueueType:          request.QueueType,
		MatchFormatID:      request.MatchFormatID,
		ModeID:             request.ModeID,
		RuleSetID:          request.RuleSetID,
		PreferredMapPoolID: preferredMapPoolID(request.PreferredMapPoolID, request.SelectedMapIDs),
	})
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":                      true,
		"queue_entry_id":          status.QueueEntryID,
		"queue_state":             status.QueueState,
		"queue_key":               status.QueueKey,
		"enqueue_unix_sec":        status.EnqueueUnixSec,
		"last_heartbeat_unix_sec": status.LastHeartbeatUnixSec,
		"assignment_id":           status.AssignmentID,
		"assignment_revision":     status.AssignmentRevision,
		"expires_at_unix_sec":     status.ExpiresAtUnixSec,
	})
}

func preferredMapPoolID(preferredMapPoolID string, selectedMapIDs []string) string {
	if preferredMapPoolID != "" {
		return preferredMapPoolID
	}
	if len(selectedMapIDs) == 0 {
		return ""
	}
	return selectedMapIDs[0]
}

func (h *MatchmakingHandler) CancelQueue(w http.ResponseWriter, r *http.Request) {
	var request struct {
		QueueEntryID string `json:"queue_entry_id"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	claims := getAuthClaims(r.Context())
	status, err := h.service.CancelQueue(r.Context(), claims.ProfileID, request.QueueEntryID)
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"ok":             true,
		"queue_entry_id": status.QueueEntryID,
		"queue_state":    status.QueueState,
		"cancel_reason":  "client_cancelled",
	})
}

func (h *MatchmakingHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	claims := getAuthClaims(r.Context())
	status, err := h.service.GetStatus(r.Context(), claims.ProfileID, r.URL.Query().Get("queue_entry_id"))
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	response := map[string]any{
		"ok":                      true,
		"queue_state":             status.QueueState,
		"queue_entry_id":          status.QueueEntryID,
		"queue_key":               status.QueueKey,
		"assignment_id":           status.AssignmentID,
		"assignment_revision":     status.AssignmentRevision,
		"queue_status_text":       status.QueueStatusText,
		"assignment_status_text":  status.AssignmentStatusText,
		"enqueue_unix_sec":        status.EnqueueUnixSec,
		"last_heartbeat_unix_sec": status.LastHeartbeatUnixSec,
		"expires_at_unix_sec":     status.ExpiresAtUnixSec,
	}
	if status.AssignmentID != "" {
		response["ticket_role"] = status.TicketRole
		response["room_id"] = status.RoomID
		response["room_kind"] = status.RoomKind
		response["server_host"] = status.ServerHost
		response["server_port"] = status.ServerPort
		response["mode_id"] = status.ModeID
		response["rule_set_id"] = status.RuleSetID
		response["map_id"] = status.MapID
		response["assigned_team_id"] = status.AssignedTeamID
		response["captain_account_id"] = status.CaptainAccountID
		response["captain_deadline_unix_sec"] = status.CaptainDeadlineUnixSec
		response["commit_deadline_unix_sec"] = status.CommitDeadlineUnixSec
	}
	httpx.WriteJSON(w, http.StatusOK, response)
}
