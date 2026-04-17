class_name RoomRuntimeContext
extends RefCounted

var room_id: String = ""
var room_flow_state: int = 0
var session_lifecycle_state: int = 0
var members: Array[int] = []
var ready_map: Dictionary = {}
var room_kind: String = ""
var topology: String = ""
var selected_map_id: String = ""
var selected_rule_set_id: String = ""
var mode_id: String = ""
var queue_type: String = ""
var match_format_id: String = "1v1"
var selected_match_mode_ids: Array[String] = []
var required_party_size: int = 1
var room_queue_state: String = "idle"
var room_queue_entry_id: String = ""
var room_queue_status_text: String = ""
var room_queue_error_code: String = ""
var room_queue_error_message: String = ""
var min_start_players: int = 2
var room_entry_kind: String = ""
var return_target: String = ""
var pending_match_id: String = ""
var last_error: Dictionary = {}
var is_host: bool = false
var local_player_id: int = 0
var host_player_id: int = 0

# LegacyMigration: Loading barrier context
var loading_phase: String = ""
var loading_ready_peers: Array[int] = []
var loading_expected_peers: Array[int] = []
var pending_room_action: String = ""


func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_flow_state": room_flow_state,
		"session_lifecycle_state": session_lifecycle_state,
		"members": members.duplicate(),
		"ready_map": ready_map.duplicate(true),
		"room_kind": room_kind,
		"topology": topology,
		"selected_map_id": selected_map_id,
		"selected_rule_set_id": selected_rule_set_id,
		"mode_id": mode_id,
		"queue_type": queue_type,
		"match_format_id": match_format_id,
		"selected_match_mode_ids": selected_match_mode_ids.duplicate(),
		"required_party_size": required_party_size,
		"room_queue_state": room_queue_state,
		"room_queue_entry_id": room_queue_entry_id,
		"room_queue_status_text": room_queue_status_text,
		"room_queue_error_code": room_queue_error_code,
		"room_queue_error_message": room_queue_error_message,
		"min_start_players": min_start_players,
		"room_entry_kind": room_entry_kind,
		"return_target": return_target,
		"pending_match_id": pending_match_id,
		"last_error": last_error.duplicate(true),
		"is_host": is_host,
		"local_player_id": local_player_id,
		"host_player_id": host_player_id,
		"loading_phase": loading_phase,
		"loading_ready_peers": loading_ready_peers.duplicate(),
		"loading_expected_peers": loading_expected_peers.duplicate(),
		"pending_room_action": pending_room_action,
	}
