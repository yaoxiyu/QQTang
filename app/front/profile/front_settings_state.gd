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
	return state


func duplicate_deep() -> FrontSettingsState:
	return FrontSettingsState.from_dict(to_dict())
