class_name MatchFormatCatalog
extends RefCounted

const MatchFormatDefScript = preload("res://content/match_formats/defs/match_format_def.gd")
const DATA_DIR := "res://content/match_formats/data/formats"

static var _formats_by_id: Dictionary = {}
static var _ordered_format_ids: Array[String] = []


static func load_all() -> void:
	_formats_by_id.clear()
	_ordered_format_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("MatchFormatCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is MatchFormatDefScript:
			push_error("MatchFormatCatalog failed to load match format def: %s" % resource_path)
			continue
		var def := resource as MatchFormatDef
		if def.match_format_id.is_empty():
			push_error("MatchFormatCatalog match_format_id is empty: %s" % resource_path)
			continue
		_formats_by_id[def.match_format_id] = {
			"resource_path": resource_path,
			"display_name": String(def.display_name if not def.display_name.is_empty() else def.match_format_id),
			"sort_order": def.sort_order,
		}

	for match_format_id in _formats_by_id.keys():
		_ordered_format_ids.append(String(match_format_id))
	_ordered_format_ids.sort_custom(func(a: String, b: String) -> bool:
		var left := get_metadata(a)
		var right := get_metadata(b)
		var left_sort := int(left.get("sort_order", 0))
		var right_sort := int(right.get("sort_order", 0))
		if left_sort == right_sort:
			return a < b
		return left_sort < right_sort
	)


static func has_match_format(match_format_id: String) -> bool:
	_ensure_loaded()
	return _formats_by_id.has(match_format_id)


static func get_match_format_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_format_ids.duplicate()


static func get_default_match_format_id() -> String:
	_ensure_loaded()
	if _ordered_format_ids.is_empty():
		return ""
	return _ordered_format_ids[0]


static func get_entries() -> Array[Dictionary]:
	_ensure_loaded()
	var entries: Array[Dictionary] = []
	for match_format_id in _ordered_format_ids:
		var metadata := get_metadata(match_format_id)
		if metadata.is_empty():
			continue
		entries.append(metadata)
	return entries


static func get_metadata(match_format_id: String) -> Dictionary:
	_ensure_loaded()
	if match_format_id.is_empty() or not has_match_format(match_format_id):
		return {}
	var resource_path := String(_formats_by_id[match_format_id].get("resource_path", ""))
	if resource_path.is_empty():
		return {}
	var resource := load(resource_path)
	if resource == null or not resource is MatchFormatDef:
		return {}
	var format_def := resource as MatchFormatDef
	return {
		"id": format_def.match_format_id,
		"match_format_id": format_def.match_format_id,
		"display_name": String(_formats_by_id[match_format_id].get("display_name", format_def.display_name)),
		"team_count": format_def.team_count,
		"required_party_size": format_def.required_party_size,
		"expected_total_player_count": format_def.expected_total_player_count,
		"map_pool_resolution_policy": format_def.map_pool_resolution_policy,
		"enabled_in_match_room": format_def.enabled_in_match_room,
		"sort_order": format_def.sort_order,
		"content_hash": format_def.content_hash,
		"resource_path": resource_path,
	}


static func get_required_party_size(match_format_id: String) -> int:
	var metadata := get_metadata(match_format_id)
	return int(metadata.get("required_party_size", 0))


static func get_expected_total_player_count(match_format_id: String) -> int:
	var metadata := get_metadata(match_format_id)
	return int(metadata.get("expected_total_player_count", 0))


static func get_match_format_resource_path(match_format_id: String) -> String:
	_ensure_loaded()
	if not has_match_format(match_format_id):
		return ""
	return String(_formats_by_id[match_format_id].get("resource_path", ""))


static func _ensure_loaded() -> void:
	if _formats_by_id.is_empty():
		load_all()
