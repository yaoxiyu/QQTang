class_name RoomMemberBindingState
extends RefCounted

var member_id: String = ""
var reconnect_token: String = ""
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
var character_skin_id: String = ""
var bubble_style_id: String = ""
var bubble_skin_id: String = ""
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
		"reconnect_token": reconnect_token,
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
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
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
	state.character_skin_id = String(data.get("character_skin_id", ""))
	state.bubble_style_id = String(data.get("bubble_style_id", ""))
	state.bubble_skin_id = String(data.get("bubble_skin_id", ""))
	state.team_id = int(data.get("team_id", 1))
	state.ready = bool(data.get("ready", false))
	state.slot_index = int(data.get("slot_index", -1))
	state.is_owner = bool(data.get("is_owner", false))
	state.connection_state = String(data.get("connection_state", "connected"))
	state.disconnect_deadline_msec = int(data.get("disconnect_deadline_msec", 0))
	state.last_room_id = String(data.get("last_room_id", ""))
	state.last_match_id = String(data.get("last_match_id", ""))
	return state
