package httpapi

import (
	"encoding/json"
	"net/http"

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
		QueueType          string `json:"queue_type"`
		ModeID             string `json:"mode_id"`
		RuleSetID          string `json:"rule_set_id"`
		PreferredMapPoolID string `json:"preferred_map_pool_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "REQUEST_INVALID_JSON", "Invalid JSON")
		return
	}
	claims := getAuthClaims(r.Context())
	status, err := h.service.EnterQueue(r.Context(), queue.EnterQueueInput{
		AccountID:          claims.AccountID,
		ProfileID:          claims.ProfileID,
		DeviceSessionID:    claims.DeviceSessionID,
		QueueType:          request.QueueType,
		ModeID:             request.ModeID,
		RuleSetID:          request.RuleSetID,
		PreferredMapPoolID: request.PreferredMapPoolID,
	})
	if err != nil {
		code, message := mapError(err)
		writeError(w, code, message, message)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
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

func (h *MatchmakingHandler) CancelQueue(w http.ResponseWriter, r *http.Request) {
	var request struct {
		QueueEntryID string `json:"queue_entry_id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&request)
	claims := getAuthClaims(r.Context())
	status, err := h.service.CancelQueue(r.Context(), claims.ProfileID, request.QueueEntryID)
	if err != nil {
		code, message := mapError(err)
		writeError(w, code, message, message)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
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
		writeError(w, code, message, message)
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
	writeJSON(w, http.StatusOK, response)
}
