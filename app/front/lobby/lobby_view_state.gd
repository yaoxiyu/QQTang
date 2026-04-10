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
		"reconnect_room_kind": reconnect_room_kind,
		"reconnect_room_display_name": reconnect_room_display_name,
		"reconnect_topology": reconnect_topology,
		"reconnect_match_id": reconnect_match_id,
		"reconnect_member_id": reconnect_member_id,
		"reconnect_token": reconnect_token,
		"reconnect_state": reconnect_state,
		"reconnect_resume_deadline_msec": reconnect_resume_deadline_msec,
		"preferred_map_id": preferred_map_id,
		"preferred_rule_id": preferred_rule_id,
		"preferred_mode_id": preferred_mode_id,
	}
