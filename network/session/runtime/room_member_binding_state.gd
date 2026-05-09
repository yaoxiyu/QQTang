class_name RoomMemberBindingState
extends RefCounted

const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")

var member_id: String = ""
var reconnect_token: String = ""
var reconnect_token_hash: String = ""
var account_id: String = ""
var profile_id: String = ""
var device_session_id: String = ""
var ticket_id: String = ""
var auth_claim_version: int = 0
var display_name_source: String = ""

var transport_peer_id: int = 0
var match_peer_id: int = 0

var player_name: String = ""
var character_id: String = ""
var bubble_style_id: String = ""
var team_id: int = 1

var ready: bool = false
var slot_index: int = -1
var is_owner: bool = false

var connection_state: String = "connected"
var disconnect_deadline_msec: int = 0
var last_room_id: String = ""
var last_match_id: String = ""

func to_dict() -> Dictionary:
	return {
		"member_id": member_id,
		"reconnect_token_hash": reconnect_token_hash,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
		"ticket_id": ticket_id,
		"auth_claim_version": auth_claim_version,
		"display_name_source": display_name_source,
		"transport_peer_id": transport_peer_id,
		"match_peer_id": match_peer_id,
		"player_name": player_name,
		"character_id": character_id,
		"bubble_style_id": bubble_style_id,
		"team_id": team_id,
		"ready": ready,
		"slot_index": slot_index,
		"is_owner": is_owner,
		"connection_state": connection_state,
		"disconnect_deadline_msec": disconnect_deadline_msec,
		"last_room_id": last_room_id,
		"last_match_id": last_match_id,
	}

static func from_dict(data: Dictionary) -> RoomMemberBindingState:
	var state := RoomMemberBindingState.new()
	state.member_id = String(data.get("member_id", ""))
	state.reconnect_token = String(data.get("reconnect_token", ""))
	state.reconnect_token_hash = String(data.get("reconnect_token_hash", ""))
	if state.reconnect_token_hash.is_empty() and not state.reconnect_token.strip_edges().is_empty():
		state.reconnect_token_hash = ResumeTokenUtilsScript.hash_resume_token(state.reconnect_token)
	state.clear_reconnect_token_plaintext()
	state.account_id = String(data.get("account_id", ""))
	state.profile_id = String(data.get("profile_id", ""))
	state.device_session_id = String(data.get("device_session_id", ""))
	state.ticket_id = String(data.get("ticket_id", ""))
	state.auth_claim_version = int(data.get("auth_claim_version", 0))
	state.display_name_source = String(data.get("display_name_source", ""))
	state.transport_peer_id = int(data.get("transport_peer_id", 0))
	state.match_peer_id = int(data.get("match_peer_id", 0))
	state.player_name = String(data.get("player_name", ""))
	state.character_id = String(data.get("character_id", ""))
	state.bubble_style_id = String(data.get("bubble_style_id", ""))
	state.team_id = int(data.get("team_id", 1))
	state.ready = bool(data.get("ready", false))
	state.slot_index = int(data.get("slot_index", -1))
	state.is_owner = bool(data.get("is_owner", false))
	state.connection_state = String(data.get("connection_state", "connected"))
	state.disconnect_deadline_msec = int(data.get("disconnect_deadline_msec", 0))
	state.last_room_id = String(data.get("last_room_id", ""))
	state.last_match_id = String(data.get("last_match_id", ""))
	return state


func set_reconnect_token_plaintext(token: String) -> void:
	reconnect_token = token.strip_edges()
	reconnect_token_hash = ResumeTokenUtilsScript.hash_resume_token(reconnect_token)


func clear_reconnect_token_plaintext() -> void:
	reconnect_token = ""


func is_reconnect_token_valid(token: String) -> bool:
	var normalized := token.strip_edges()
	if normalized.is_empty() or reconnect_token_hash.is_empty():
		return false
	return ResumeTokenUtilsScript.hash_resume_token(normalized) == reconnect_token_hash
