class_name LobbyViewState
extends RefCounted

var profile_name: String = ""
var default_character_id: String = ""
var default_character_skin_id: String = ""
var default_bubble_style_id: String = ""
var default_bubble_skin_id: String = ""
var last_server_host: String = "127.0.0.1"
var last_server_port: int = 9000
var last_room_id: String = ""
var reconnect_room_id: String = ""
var reconnect_host: String = ""
var reconnect_port: int = 0
var preferred_map_id: String = ""
var preferred_rule_id: String = ""
var preferred_mode_id: String = ""


func to_dict() -> Dictionary:
	return {
		"profile_name": profile_name,
		"default_character_id": default_character_id,
		"default_character_skin_id": default_character_skin_id,
		"default_bubble_style_id": default_bubble_style_id,
		"default_bubble_skin_id": default_bubble_skin_id,
		"last_server_host": last_server_host,
		"last_server_port": last_server_port,
		"last_room_id": last_room_id,
		"reconnect_room_id": reconnect_room_id,
		"reconnect_host": reconnect_host,
		"reconnect_port": reconnect_port,
		"preferred_map_id": preferred_map_id,
		"preferred_rule_id": preferred_rule_id,
		"preferred_mode_id": preferred_mode_id,
	}
