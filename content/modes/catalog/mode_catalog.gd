class_name ModeCatalog
extends RefCounted

const MODE_REGISTRY := {
	"mode_classic": {
		"display_name": "经典模式",
		"resource_path": "res://content/modes/resources/mode_classic.tres",
		"is_default": true,
	},
	"mode_quick_match": {
		"display_name": "快速对局",
		"resource_path": "res://content/modes/resources/mode_quick_match.tres",
	},
}


static func get_mode_ids() -> Array[String]:
	var mode_ids: Array[String] = []
	for mode_id in MODE_REGISTRY.keys():
		mode_ids.append(String(mode_id))
	mode_ids.sort()
	return mode_ids


static func get_default_mode_id() -> String:
	for mode_id in get_mode_ids():
		if bool(MODE_REGISTRY[mode_id].get("is_default", false)):
			return mode_id
	var mode_ids := get_mode_ids()
	if mode_ids.is_empty():
		return ""
	return mode_ids[0]


static func has_mode(mode_id: String) -> bool:
	return MODE_REGISTRY.has(mode_id)


static func get_mode_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for mode_id in get_mode_ids():
		var metadata := get_mode_metadata(mode_id)
		if metadata.is_empty():
			continue
		entries.append(metadata)
	return entries


static func get_mode_resource_path(mode_id: String) -> String:
	if not has_mode(mode_id):
		return ""
	return String(MODE_REGISTRY[mode_id].get("resource_path", ""))


static func get_mode_metadata(mode_id: String) -> Dictionary:
	if mode_id.is_empty() or not has_mode(mode_id):
		return {}
	var resource_path := get_mode_resource_path(mode_id)
	if resource_path.is_empty():
		return {}
	var resource := load(resource_path)
	if resource == null or not resource is ModeDef:
		return {}
	var mode_def := resource as ModeDef
	return {
		"id": mode_id,
		"mode_id": mode_def.mode_id,
		"display_name": String(MODE_REGISTRY[mode_id].get("display_name", mode_def.display_name)),
		"rule_set_id": mode_def.rule_set_id,
		"default_map_id": mode_def.default_map_id,
		"min_player_count": mode_def.min_player_count,
		"max_player_count": mode_def.max_player_count,
		"allow_character_select": mode_def.allow_character_select,
		"allow_bubble_select": mode_def.allow_bubble_select,
		"allow_map_select": mode_def.allow_map_select,
		"hud_layout_id": mode_def.hud_layout_id,
		"content_hash": mode_def.content_hash,
		"resource_path": resource_path,
	}
