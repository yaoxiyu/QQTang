class_name FrontSettingsState
extends RefCounted

var remember_profile: bool = true
var auto_enter_lobby: bool = false
var last_server_host: String = "127.0.0.1"
var last_server_port: int = 9000
var last_room_id: String = ""
var reconnect_room_id: String = ""
var reconnect_host: String = ""
var reconnect_port: int = 0

# Phase16: Reconnect ticket extension
var reconnect_room_kind: String = ""
var reconnect_room_display_name: String = ""
var reconnect_topology: String = ""
var reconnect_match_id: String = ""

# Phase17: Member session resume ticket
var reconnect_member_id: String = ""
var reconnect_token: String = ""
var reconnect_state: String = ""
var reconnect_resume_deadline_msec: int = 0


func to_dict() -> Dictionary:
	return {
		"remember_profile": remember_profile,
		"auto_enter_lobby": auto_enter_lobby,
		"last_server_host": last_server_host,
		"last_server_port": last_server_port,
		"last_room_id": last_room_id,
		"reconnect_room_id": reconnect_room_id,
		"reconnect_host": reconnect_host,
		"reconnect_port": reconnect_port,
		"reconnect_room_kind": reconnect_room_kind,
		"reconnect_room_display_name": reconnect_room_display_name,
		"reconnect_topology": reconnect_topology,
		"reconnect_match_id": reconnect_match_id,
		"reconnect_member_id": reconnect_member_id,
		"reconnect_token": reconnect_token,
		"reconnect_state": reconnect_state,
		"reconnect_resume_deadline_msec": reconnect_resume_deadline_msec,
	}


static func from_dict(data: Dictionary) -> FrontSettingsState:
	var state := FrontSettingsState.new()
	state.remember_profile = bool(data.get("remember_profile", true))
	state.auto_enter_lobby = bool(data.get("auto_enter_lobby", false))
	state.last_server_host = String(data.get("last_server_host", "127.0.0.1"))
	state.last_server_port = int(data.get("last_server_port", 9000))
	state.last_room_id = String(data.get("last_room_id", ""))
	state.reconnect_room_id = String(data.get("reconnect_room_id", ""))
	state.reconnect_host = String(data.get("reconnect_host", ""))
	state.reconnect_port = int(data.get("reconnect_port", 0))
	state.reconnect_room_kind = String(data.get("reconnect_room_kind", ""))
	state.reconnect_room_display_name = String(data.get("reconnect_room_display_name", ""))
	state.reconnect_topology = String(data.get("reconnect_topology", ""))
	state.reconnect_match_id = String(data.get("reconnect_match_id", ""))
	# Phase17: Member session fields
	state.reconnect_member_id = String(data.get("reconnect_member_id", ""))
	state.reconnect_token = String(data.get("reconnect_token", ""))
	state.reconnect_state = String(data.get("reconnect_state", ""))
	state.reconnect_resume_deadline_msec = int(data.get("reconnect_resume_deadline_msec", 0))
	return state


func duplicate_deep() -> FrontSettingsState:
	return FrontSettingsState.from_dict(to_dict())


func clear_reconnect_ticket() -> void:
	reconnect_room_id = ""
	reconnect_host = ""
	reconnect_port = 0
	reconnect_room_kind = ""
	reconnect_room_display_name = ""
	reconnect_topology = ""
	reconnect_match_id = ""
	reconnect_member_id = ""
	reconnect_token = ""
	reconnect_state = ""
	reconnect_resume_deadline_msec = 0
