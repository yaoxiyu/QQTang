package httpapi

import (
	"net/http"

	"qqtang/services/game_service/internal/platform/httpx"
	"qqtang/services/game_service/internal/queue"
)

type PartyMatchmakingHandler struct {
	service *queue.Service
}

func NewPartyMatchmakingHandler(service *queue.Service) *PartyMatchmakingHandler {
	return &PartyMatchmakingHandler{service: service}
}

func (h *PartyMatchmakingHandler) EnterPartyQueue(w http.ResponseWriter, r *http.Request) {
	var request struct {
		PartyRoomID     string                        `json:"party_room_id"`
		QueueType       string                        `json:"queue_type"`
		MatchFormatID   string                        `json:"match_format_id"`
		SelectedModeIDs []string                      `json:"selected_mode_ids"`
		Members         []queue.PartyQueueMemberInput `json:"members"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	status, err := h.service.EnterPartyQueue(r.Context(), queue.EnterPartyQueueInput{
		PartyRoomID:     request.PartyRoomID,
		QueueType:       request.QueueType,
		MatchFormatID:   request.MatchFormatID,
		SelectedModeIDs: request.SelectedModeIDs,
		Members:         request.Members,
	})
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, partyStatusResponse(status))
}

func (h *PartyMatchmakingHandler) CancelPartyQueue(w http.ResponseWriter, r *http.Request) {
	var request struct {
		PartyRoomID  string `json:"party_room_id"`
		QueueEntryID string `json:"queue_entry_id"`
	}
	if err := httpx.DecodeJSONBody(w, r, &request); err != nil {
		httpx.WriteInvalidRequestBody(w)
		return
	}
	status, err := h.service.CancelPartyQueue(r.Context(), request.PartyRoomID, request.QueueEntryID)
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, partyStatusResponse(status))
}

func (h *PartyMatchmakingHandler) GetPartyQueueStatus(w http.ResponseWriter, r *http.Request) {
	status, err := h.service.GetPartyQueueStatus(
		r.Context(),
		r.URL.Query().Get("party_room_id"),
		r.URL.Query().Get("queue_entry_id"),
	)
	if err != nil {
		code, message := mapError(err)
		httpx.WriteError(w, code, message, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, partyStatusResponse(status))
}

func partyStatusResponse(status queue.PartyQueueStatus) map[string]any {
	response := map[string]any{
		"ok":                      true,
		"queue_state":             status.QueueState,
		"queue_entry_id":          status.QueueEntryID,
		"party_queue_entry_id":    status.QueueEntryID,
		"party_room_id":           status.PartyRoomID,
		"queue_key":               status.QueueKey,
		"queue_type":              status.QueueType,
		"match_format_id":         status.MatchFormatID,
		"selected_mode_ids":       status.SelectedModeIDs,
		"assignment_id":           status.AssignmentID,
		"assignment_revision":     status.AssignmentRevision,
		"queue_status_text":       status.QueueStatusText,
		"assignment_status_text":  status.AssignmentStatusText,
		"enqueue_unix_sec":        status.EnqueueUnixSec,
		"last_heartbeat_unix_sec": status.LastHeartbeatUnixSec,
		"expires_at_unix_sec":     status.ExpiresAtUnixSec,
	}
	if status.AssignmentID != "" {
		response["room_id"] = status.RoomID
		response["room_kind"] = status.RoomKind
		response["server_host"] = status.ServerHost
		response["server_port"] = status.ServerPort
		response["mode_id"] = status.ModeID
		response["rule_set_id"] = status.RuleSetID
		response["map_id"] = status.MapID
		response["captain_account_id"] = status.CaptainAccountID
		response["captain_deadline_unix_sec"] = status.CaptainDeadlineUnixSec
		response["commit_deadline_unix_sec"] = status.CommitDeadlineUnixSec
	}
	return response
}
