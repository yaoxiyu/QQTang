class_name ModeCatalog
extends RefCounted

const ModeDefScript = preload("res://content/modes/defs/mode_def.gd")
const DATA_DIR := "res://content/modes/data/mode"

static var _modes_by_id: Dictionary = {}
static var _ordered_mode_ids: Array[String] = []


static func load_all() -> void:
	_modes_by_id.clear()
	_ordered_mode_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("ModeCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is ModeDefScript:
			push_error("ModeCatalog failed to load mode def: %s" % resource_path)
			continue
		var def := resource as ModeDef
		if def.mode_id.is_empty():
			push_error("ModeCatalog mode_id is empty: %s" % resource_path)
			continue
		_modes_by_id[def.mode_id] = {
			"resource_path": resource_path,
			"display_name": String(def.display_name if not def.display_name.is_empty() else def.mode_id),
		}

	for mode_id in _modes_by_id.keys():
		_ordered_mode_ids.append(String(mode_id))
	_ordered_mode_ids.sort()


static func get_mode_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_mode_ids.duplicate()


static func get_default_mode_id() -> String:
	_ensure_loaded()
	if _ordered_mode_ids.is_empty():
		return ""
	return _ordered_mode_ids[0]


static func has_mode(mode_id: String) -> bool:
	_ensure_loaded()
	return _modes_by_id.has(mode_id)


static func get_mode_entries() -> Array[Dictionary]:
	_ensure_loaded()
	var entries: Array[Dictionary] = []
	for mode_id in _ordered_mode_ids:
		var metadata := get_mode_metadata(mode_id)
		if metadata.is_empty():
			continue
		entries.append(metadata)
	return entries


static func get_mode_resource_path(mode_id: String) -> String:
	_ensure_loaded()
	if not has_mode(mode_id):
		return ""
	return String(_modes_by_id[mode_id].get("resource_path", ""))


static func get_mode_metadata(mode_id: String) -> Dictionary:
	_ensure_loaded()
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
		"display_name": String(_modes_by_id[mode_id].get("display_name", mode_def.display_name)),
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


static func _ensure_loaded() -> void:
	if _modes_by_id.is_empty():
		load_all()
