class_name RoomRuntimeContext
extends RefCounted

var room_id: String = ""
var room_flow_state: int = 0
var session_lifecycle_state: int = 0
var members: Array[int] = []
var ready_map: Dictionary = {}
var selected_map_id: String = ""
var selected_rule_set_id: String = ""
var pending_match_id: String = ""
var last_error: Dictionary = {}
var is_host: bool = false
var local_player_id: int = 0
var host_player_id: int = 0


func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_flow_state": room_flow_state,
		"session_lifecycle_state": session_lifecycle_state,
		"members": members.duplicate(),
		"ready_map": ready_map.duplicate(true),
		"selected_map_id": selected_map_id,
		"selected_rule_set_id": selected_rule_set_id,
		"pending_match_id": pending_match_id,
		"last_error": last_error.duplicate(true),
		"is_host": is_host,
		"local_player_id": local_player_id,
		"host_player_id": host_player_id,
	}
