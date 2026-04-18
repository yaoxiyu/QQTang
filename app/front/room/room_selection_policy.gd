extends RefCounted

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")


static func resolve_default_selection(entry_context: RoomEntryContext, preferred_map_id: String = "") -> Dictionary:
	if entry_context != null and String(entry_context.room_kind) == FrontRoomKindScript.MATCHMADE_ROOM:
		return {
			"map_id": String(entry_context.locked_map_id),
			"rule_set_id": String(entry_context.locked_rule_set_id),
			"mode_id": String(entry_context.locked_mode_id),
		}
	var resolved_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id(preferred_map_id)
	var binding := MapSelectionCatalogScript.get_map_binding(resolved_map_id)
	if binding.is_empty():
		return {
			"map_id": resolved_map_id,
			"rule_set_id": "",
			"mode_id": "",
		}
	return {
		"map_id": resolved_map_id,
		"rule_set_id": String(binding.get("bound_rule_set_id", "")),
		"mode_id": String(binding.get("bound_mode_id", "")),
	}


static func sanitize_connection_selection(config: ClientConnectionConfig, should_sanitize_selection: bool = true) -> void:
	if config == null:
		return
	if not should_sanitize_selection:
		return
	if config.selected_map_id.is_empty():
		config.selected_map_id = MapSelectionCatalogScript.get_default_custom_room_map_id()
	var binding := MapSelectionCatalogScript.get_map_binding(config.selected_map_id)
	if not binding.is_empty():
		config.selected_rule_set_id = String(binding.get("bound_rule_set_id", config.selected_rule_set_id))
		config.selected_mode_id = String(binding.get("bound_mode_id", config.selected_mode_id))
	if not ModeCatalogScript.has_mode(config.selected_mode_id):
		config.selected_mode_id = ModeCatalogScript.get_default_mode_id()


static func resolve_locked_team_id(snapshot: RoomSnapshot, entry_context: RoomEntryContext, local_peer_id: int, fallback_team_id: int) -> int:
	if snapshot != null:
		for member in snapshot.members:
			if member != null and member.peer_id == local_peer_id and int(member.team_id) > 0:
				return int(member.team_id)
	if entry_context != null and int(entry_context.assigned_team_id) > 0:
		return int(entry_context.assigned_team_id)
	return fallback_team_id
