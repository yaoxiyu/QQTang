package httpapi

import (
	"net/http"
	"strings"

	"qqtang/services/game_service/internal/assignment"
)

type InternalAssignmentHandler struct {
	service *assignment.Service
}

func NewInternalAssignmentHandler(service *assignment.Service) *InternalAssignmentHandler {
	return &InternalAssignmentHandler{service: service}
}

func (h *InternalAssignmentHandler) GetGrant(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/internal/v1/assignments/")
	assignmentID := strings.TrimSuffix(path, "/grant")
	grant, err := h.service.GetGrant(
		r.Context(),
		assignmentID,
		r.URL.Query().Get("account_id"),
		r.URL.Query().Get("profile_id"),
		r.URL.Query().Get("room_kind"),
	)
	if err != nil {
		code, message := mapError(err)
		writeError(w, code, message, message)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "grant_state": grant.GrantState, "assignment_id": grant.AssignmentID,
		"assignment_revision": grant.AssignmentRevision, "match_source": grant.MatchSource, "queue_type": grant.QueueType,
		"ticket_role": grant.TicketRole, "room_id": grant.RoomID, "room_kind": grant.RoomKind, "match_id": grant.MatchID,
		"season_id": grant.SeasonID, "server_host": grant.ServerHost, "server_port": grant.ServerPort,
		"locked_map_id": grant.LockedMapID, "locked_rule_set_id": grant.LockedRuleSetID, "locked_mode_id": grant.LockedModeID,
		"assigned_team_id": grant.AssignedTeamID, "expected_member_count": grant.ExpectedMemberCount,
		"auto_ready_on_join": grant.AutoReadyOnJoin, "hidden_room": grant.HiddenRoom,
		"captain_account_id": grant.CaptainAccountID, "captain_deadline_unix_sec": grant.CaptainDeadlineUnixSec,
		"commit_deadline_unix_sec": grant.CommitDeadlineUnixSec})
}
