class_name MatchmakingAssignmentState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/matchmaking/matchmaking_assignment_state.gd")

var assignment_id: String = ""
var assignment_revision: int = 0
var assignment_status_text: String = ""
var ticket_role: String = ""
var room_id: String = ""
var room_kind: String = ""
var server_host: String = ""
var server_port: int = 0
var mode_id: String = ""
var rule_set_id: String = ""
var map_id: String = ""
var assigned_team_id: int = 0
var captain_account_id: String = ""
var captain_deadline_unix_sec: int = 0
var commit_deadline_unix_sec: int = 0


static func from_response(data: Dictionary) -> MatchmakingAssignmentState:
	var state := SELF_SCRIPT.new()
	state.assignment_id = String(data.get("assignment_id", ""))
	state.assignment_revision = int(data.get("assignment_revision", 0))
	state.assignment_status_text = String(data.get("assignment_status_text", ""))
	state.ticket_role = String(data.get("ticket_role", ""))
	state.room_id = String(data.get("room_id", ""))
	state.room_kind = String(data.get("room_kind", ""))
	state.server_host = String(data.get("server_host", ""))
	state.server_port = int(data.get("server_port", 0))
	state.mode_id = String(data.get("mode_id", ""))
	state.rule_set_id = String(data.get("rule_set_id", ""))
	state.map_id = String(data.get("map_id", ""))
	state.assigned_team_id = int(data.get("assigned_team_id", 0))
	state.captain_account_id = String(data.get("captain_account_id", ""))
	state.captain_deadline_unix_sec = int(data.get("captain_deadline_unix_sec", 0))
	state.commit_deadline_unix_sec = int(data.get("commit_deadline_unix_sec", 0))
	return state
