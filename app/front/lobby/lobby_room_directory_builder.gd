class_name LobbyRoomDirectoryBuilder
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")


func build_view_models(snapshot: RoomDirectorySnapshot) -> Array[Dictionary]:
	var view_models: Array[Dictionary] = []
	if snapshot == null:
		return view_models
	for entry in snapshot.entries:
		if entry == null:
			continue
		var room_display_name := String(entry.room_display_name if not String(entry.room_display_name).is_empty() else entry.room_id)
		view_models.append({
			"room_id": String(entry.room_id),
			"room_display_name": room_display_name,
			"room_kind": String(entry.room_kind),
			"owner_name": _resolve_owner_name(entry),
			"map_name": _resolve_map_name(String(entry.selected_map_id)),
			"rule_name": _resolve_rule_name(String(entry.rule_set_id)),
			"mode_name": _resolve_mode_name(String(entry.mode_id)),
			"member_text": "%d/%d" % [int(entry.member_count), int(entry.max_players)],
			"joinable": bool(entry.joinable),
			"match_active": bool(entry.match_active),
			"summary_text": _build_summary_text(entry, room_display_name),
		})
	return view_models


func _build_summary_text(entry: RoomDirectoryEntry, room_display_name: String) -> String:
	var suffix := ""
	if bool(entry.match_active):
		suffix = " [In Match]"
	elif int(entry.member_count) >= int(entry.max_players):
		suffix = " [Full]"
	return "%s | %s | %s | %s | %s%s" % [
		room_display_name,
		_resolve_owner_name(entry),
		_resolve_map_name(String(entry.selected_map_id)),
		_resolve_rule_name(String(entry.rule_set_id)),
		"%d/%d" % [int(entry.member_count), int(entry.max_players)],
		suffix,
	]


func _resolve_owner_name(entry: RoomDirectoryEntry) -> String:
	var owner_name := String(entry.owner_name)
	if not owner_name.is_empty():
		return owner_name
	return "Owner %d" % int(entry.owner_peer_id)


func _resolve_map_name(map_id: String) -> String:
	var metadata := MapCatalogScript.get_map_metadata(map_id)
	return String(metadata.get("display_name", map_id if not map_id.is_empty() else "-"))


func _resolve_rule_name(rule_set_id: String) -> String:
	var metadata := RuleSetCatalogScript.get_rule_metadata(rule_set_id)
	return String(metadata.get("display_name", rule_set_id if not rule_set_id.is_empty() else "-"))


func _resolve_mode_name(mode_id: String) -> String:
	var metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	return String(metadata.get("display_name", mode_id if not mode_id.is_empty() else "-"))
