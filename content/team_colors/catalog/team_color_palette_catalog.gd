class_name TeamColorPaletteCatalog
extends RefCounted

const TeamColorPaletteDefScript = preload("res://content/team_colors/defs/team_color_palette_def.gd")
const DATA_DIR := "res://content/team_colors/data/palettes"

static var _palettes_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_palettes_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("TeamColorPaletteCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is TeamColorPaletteDefScript:
			push_error("TeamColorPaletteCatalog failed to load palette def: %s" % resource_path)
			continue
		var def := resource
		if def.palette_id.is_empty():
			push_error("TeamColorPaletteCatalog palette_id is empty: %s" % resource_path)
			continue
		if _palettes_by_id.has(def.palette_id):
			push_error("TeamColorPaletteCatalog duplicate palette_id: %s" % def.palette_id)
			continue
		_palettes_by_id[def.palette_id] = def

	for palette_id in _palettes_by_id.keys():
		_ordered_ids.append(String(palette_id))
	_ordered_ids.sort()


static func get_by_id(palette_id: String) -> Resource:
	if _palettes_by_id.is_empty():
		load_all()
	if not _palettes_by_id.has(palette_id):
		return null
	return _palettes_by_id[palette_id] as Resource


static func get_all() -> Array[Resource]:
	if _palettes_by_id.is_empty():
		load_all()
	var result: Array[Resource] = []
	for palette_id in _ordered_ids:
		result.append(_palettes_by_id[palette_id] as Resource)
	return result


static func has_id(palette_id: String) -> bool:
	if _palettes_by_id.is_empty():
		load_all()
	return _palettes_by_id.has(palette_id)
