class_name RoomSnapshot
extends RefCounted

var room_id: String = ""
var room_kind: String = ""
var topology: String = ""
var owner_peer_id: int = 0
var members: Array[RoomMemberState] = []
var room_display_name: String = ""
var selected_map_id: String = ""
var rule_set_id: String = ""
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
var queue_status_text: String = ""
var queue_error_code: String = ""
var queue_user_message: String = ""
var queue_entry_id: String = ""
var min_start_players: int = 2
var all_ready: bool = false
var max_players: int = 0
var match_active: bool = false

# LegacyMigration: Room lifecycle & battle handoff
var room_lifecycle_state: String = "idle"
var room_phase: String = "idle"
var room_phase_reason: String = "none"
var current_assignment_id: String = ""
var current_battle_id: String = ""
var current_match_id: String = ""
var queue_phase: String = "idle"
var queue_terminal_reason: String = "none"
var battle_allocation_state: String = ""
var battle_phase: String = "idle"
var battle_terminal_reason: String = "none"
var battle_status_text: String = ""
var battle_server_host: String = ""
var battle_server_port: int = 0
var room_return_policy: String = "return_to_source_room"
var battle_entry_ready: bool = false
var can_toggle_ready: bool = false
var can_start_manual_battle: bool = false
var can_update_selection: bool = false
var can_update_match_room_config: bool = false
var can_enter_queue: bool = false
var can_cancel_queue: bool = false
var can_leave_room: bool = false


func to_dict() -> Dictionary:
	var member_dicts: Array[Dictionary] = []
	for member in members:
		if member == null:
			continue
		member_dicts.append(member.to_dict())

	return {
		"room_id": room_id,
		"room_kind": room_kind,
		"topology": topology,
		"owner_peer_id": owner_peer_id,
		"members": member_dicts,
		"room_display_name": room_display_name,
		"selected_map_id": selected_map_id,
		"rule_set_id": rule_set_id,
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
		"queue_status_text": queue_status_text,
		"queue_error_code": queue_error_code,
		"queue_user_message": queue_user_message,
		"queue_entry_id": queue_entry_id,
		"min_start_players": min_start_players,
		"all_ready": all_ready,
		"max_players": max_players,
		"match_active": match_active,
		"room_lifecycle_state": room_lifecycle_state,
		"room_phase": room_phase,
		"room_phase_reason": room_phase_reason,
		"current_assignment_id": current_assignment_id,
		"current_battle_id": current_battle_id,
		"current_match_id": current_match_id,
		"queue_phase": queue_phase,
		"queue_terminal_reason": queue_terminal_reason,
		"battle_allocation_state": battle_allocation_state,
		"battle_phase": battle_phase,
		"battle_terminal_reason": battle_terminal_reason,
		"battle_status_text": battle_status_text,
		"battle_server_host": battle_server_host,
		"battle_server_port": battle_server_port,
		"room_return_policy": room_return_policy,
		"battle_entry_ready": battle_entry_ready,
		"can_toggle_ready": can_toggle_ready,
		"can_start_manual_battle": can_start_manual_battle,
		"can_update_selection": can_update_selection,
		"can_update_match_room_config": can_update_match_room_config,
		"can_enter_queue": can_enter_queue,
		"can_cancel_queue": can_cancel_queue,
		"can_leave_room": can_leave_room,
	}


static func from_dict(data: Dictionary) -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = String(data.get("room_id", ""))
	snapshot.room_kind = String(data.get("room_kind", ""))
	snapshot.topology = String(data.get("topology", ""))
	snapshot.owner_peer_id = int(data.get("owner_peer_id", 0))
	snapshot.room_display_name = String(data.get("room_display_name", ""))
	snapshot.selected_map_id = String(data.get("selected_map_id", ""))
	snapshot.rule_set_id = String(data.get("rule_set_id", ""))
	snapshot.mode_id = String(data.get("mode_id", ""))
	snapshot.queue_type = String(data.get("queue_type", ""))
	snapshot.match_format_id = String(data.get("match_format_id", "1v1"))
	snapshot.selected_match_mode_ids = _to_string_array(data.get("selected_match_mode_ids", []))
	snapshot.required_party_size = int(data.get("required_party_size", 1))
	snapshot.room_queue_state = String(data.get("room_queue_state", "idle"))
	snapshot.room_queue_entry_id = String(data.get("room_queue_entry_id", ""))
	snapshot.room_queue_status_text = String(data.get("room_queue_status_text", ""))
	snapshot.room_queue_error_code = String(data.get("room_queue_error_code", ""))
	snapshot.room_queue_error_message = String(data.get("room_queue_error_message", ""))
	snapshot.queue_status_text = String(data.get("queue_status_text", snapshot.room_queue_status_text))
	snapshot.queue_error_code = String(data.get("queue_error_code", snapshot.room_queue_error_code))
	snapshot.queue_user_message = String(data.get("queue_user_message", snapshot.room_queue_error_message))
	snapshot.queue_entry_id = String(data.get("queue_entry_id", snapshot.room_queue_entry_id))
	snapshot.min_start_players = int(data.get("min_start_players", 2))
	snapshot.all_ready = bool(data.get("all_ready", false))
	snapshot.max_players = int(data.get("max_players", 0))
	snapshot.match_active = bool(data.get("match_active", false))
	snapshot.room_lifecycle_state = String(data.get("room_lifecycle_state", "idle"))
	snapshot.room_phase = String(data.get("room_phase", "idle"))
	snapshot.room_phase_reason = String(data.get("room_phase_reason", "none"))
	snapshot.current_assignment_id = String(data.get("current_assignment_id", ""))
	snapshot.current_battle_id = String(data.get("current_battle_id", ""))
	snapshot.current_match_id = String(data.get("current_match_id", ""))
	snapshot.queue_phase = String(data.get("queue_phase", "idle"))
	snapshot.queue_terminal_reason = String(data.get("queue_terminal_reason", "none"))
	snapshot.battle_allocation_state = String(data.get("battle_allocation_state", ""))
	snapshot.battle_phase = String(data.get("battle_phase", "idle"))
	snapshot.battle_terminal_reason = String(data.get("battle_terminal_reason", "none"))
	snapshot.battle_status_text = String(data.get("battle_status_text", ""))
	snapshot.battle_server_host = String(data.get("battle_server_host", ""))
	snapshot.battle_server_port = int(data.get("battle_server_port", 0))
	snapshot.room_return_policy = String(data.get("room_return_policy", "return_to_source_room"))
	snapshot.battle_entry_ready = bool(data.get("battle_entry_ready", false))
	snapshot.can_toggle_ready = bool(data.get("can_toggle_ready", false))
	snapshot.can_start_manual_battle = bool(data.get("can_start_manual_battle", false))
	snapshot.can_update_selection = bool(data.get("can_update_selection", false))
	snapshot.can_update_match_room_config = bool(data.get("can_update_match_room_config", false))
	snapshot.can_enter_queue = bool(data.get("can_enter_queue", false))
	snapshot.can_cancel_queue = bool(data.get("can_cancel_queue", false))
	snapshot.can_leave_room = bool(data.get("can_leave_room", false))

	var member_entries: Array = data.get("members", [])
	for entry in member_entries:
		if entry is Dictionary:
			snapshot.members.append(RoomMemberState.from_dict(entry))

	return snapshot


func duplicate_deep() -> RoomSnapshot:
	return RoomSnapshot.from_dict(to_dict())


func sorted_members() -> Array[RoomMemberState]:
	var copied: Array[RoomMemberState] = []
	for member in members:
		if member != null:
			copied.append(member.duplicate_deep())

	copied.sort_custom(func(a: RoomMemberState, b: RoomMemberState) -> bool:
		if a.slot_index == b.slot_index:
			return a.peer_id < b.peer_id
		return a.slot_index < b.slot_index
	)
	return copied


func member_count() -> int:
	return members.size()


func has_member(peer_id: int) -> bool:
	for member in members:
		if member != null and member.peer_id == peer_id:
			return true
	return false


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result
