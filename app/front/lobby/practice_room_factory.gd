class_name PracticeRoomFactory
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const PRACTICE_ROOM_LOG_PREFIX := "[QQT_PRACTICE]"

var room_session_controller: Node = null


func configure(p_room_session_controller: Node) -> void:
	room_session_controller = p_room_session_controller


func create_practice_room(
	local_profile_state: PlayerProfileState,
	map_id: String,
	rule_id: String,
	mode_id: String,
	local_peer_id: int = 1
) -> Dictionary:
	if room_session_controller == null:
		return _fail("PRACTICE_ROOM_CONTROLLER_MISSING", "Room session controller is not configured")
	if not room_session_controller.has_method("configure_practice_room"):
		return _fail("PRACTICE_ROOM_UNSUPPORTED", "Practice room API is not available yet")

	var resolved_map_id := _resolve_map_id(map_id)
	var resolved_rule_id := _resolve_rule_id(resolved_map_id, rule_id)
	var resolved_mode_id := _resolve_mode_id(resolved_map_id, mode_id)
	if resolved_map_id.is_empty() or resolved_rule_id.is_empty() or resolved_mode_id.is_empty():
		_log_practice("practice_selection_invalid", {
			"preferred_map_id": map_id,
			"preferred_rule_id": rule_id,
			"preferred_mode_id": mode_id,
			"resolved_map_id": resolved_map_id,
			"resolved_rule_id": resolved_rule_id,
			"resolved_mode_id": resolved_mode_id,
		})
		return _fail("PRACTICE_ROOM_SELECTION_INVALID", "Practice room selection is invalid")
	_log_practice("practice_selection_resolved", {
		"preferred_map_id": map_id,
		"preferred_rule_id": rule_id,
		"preferred_mode_id": mode_id,
		"resolved_map_id": resolved_map_id,
		"resolved_rule_id": resolved_rule_id,
		"resolved_mode_id": resolved_mode_id,
		"local_peer_id": local_peer_id,
	})

	room_session_controller.configure_practice_room(
		local_profile_state,
		resolved_map_id,
		resolved_rule_id,
		resolved_mode_id,
		local_peer_id
	)

	var entry_context := RoomEntryContextScript.new()
	entry_context.entry_kind = FrontEntryKindScript.PRACTICE
	entry_context.room_kind = FrontRoomKindScript.PRACTICE
	entry_context.topology = FrontTopologyScript.LOCAL
	entry_context.return_target = FrontReturnTargetScript.LOBBY
	entry_context.should_auto_connect = false
	entry_context.should_auto_join = false
	entry_context.target_room_id = "practice"

	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": entry_context,
	}


func _resolve_map_id(map_id: String) -> String:
	var trimmed := map_id.strip_edges()
	var resolved_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id(trimmed)
	return resolved_map_id if not resolved_map_id.is_empty() else trimmed


func _resolve_rule_id(map_id: String, rule_id: String) -> String:
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if not binding.is_empty():
		return String(binding.get("bound_rule_set_id", ""))
	return rule_id.strip_edges()


func _resolve_mode_id(map_id: String, mode_id: String) -> String:
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if not binding.is_empty():
		return String(binding.get("bound_mode_id", ""))
	return mode_id.strip_edges()


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
		"entry_context": null,
	}


func _log_practice(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[practice_room_factory] %s %s" % [PRACTICE_ROOM_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.practice")
