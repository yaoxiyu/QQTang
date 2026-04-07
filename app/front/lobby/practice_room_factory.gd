class_name PracticeRoomFactory
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

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
	var resolved_rule_id := _resolve_rule_id(rule_id)
	var resolved_mode_id := _resolve_mode_id(mode_id)
	if resolved_map_id.is_empty() or resolved_rule_id.is_empty() or resolved_mode_id.is_empty():
		return _fail("PRACTICE_ROOM_SELECTION_INVALID", "Practice room selection is invalid")

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
	if not trimmed.is_empty() and MapCatalogScript.has_map(trimmed):
		return trimmed
	return MapCatalogScript.get_default_map_id()


func _resolve_rule_id(rule_id: String) -> String:
	var trimmed := rule_id.strip_edges()
	if not trimmed.is_empty() and RuleSetCatalogScript.has_rule(trimmed):
		return trimmed
	return RuleSetCatalogScript.get_default_rule_id()


func _resolve_mode_id(mode_id: String) -> String:
	var trimmed := mode_id.strip_edges()
	if not trimmed.is_empty() and ModeCatalogScript.has_mode(trimmed):
		return trimmed
	return ModeCatalogScript.get_default_mode_id()


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
		"entry_context": null,
	}
