class_name MapThemeCatalog
extends RefCounted

const MapThemeDefScript = preload("res://content/map_themes/defs/map_theme_def.gd")
const DATA_DIR := "res://content/map_themes/data/theme"

static var _themes_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_themes_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("MapThemeCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is MapThemeDefScript:
			push_error("MapThemeCatalog failed to load theme def: %s" % resource_path)
			continue
		var def := resource as MapThemeDef
		if def.theme_id.is_empty():
			push_error("MapThemeCatalog theme_id is empty: %s" % resource_path)
			continue
		_themes_by_id[def.theme_id] = def

	for theme_id in _themes_by_id.keys():
		_ordered_ids.append(String(theme_id))
	_ordered_ids.sort()


static func get_by_id(theme_id: String) -> MapThemeDef:
	if _themes_by_id.is_empty():
		load_all()
	if not _themes_by_id.has(theme_id):
		return null
	return _themes_by_id[theme_id] as MapThemeDef


static func get_all() -> Array[MapThemeDef]:
	if _themes_by_id.is_empty():
		load_all()
	var result: Array[MapThemeDef] = []
	for theme_id in _ordered_ids:
		result.append(_themes_by_id[theme_id] as MapThemeDef)
	return result


static func has_id(theme_id: String) -> bool:
	if _themes_by_id.is_empty():
		load_all()
	return _themes_by_id.has(theme_id)
