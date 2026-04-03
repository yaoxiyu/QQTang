class_name BubbleSkinCatalog
extends RefCounted

const BubbleSkinDefScript = preload("res://content/bubble_skins/defs/bubble_skin_def.gd")
const DATA_DIR := "res://content/bubble_skins/data/skins"

static var _skins_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_skins_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("BubbleSkinCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is BubbleSkinDefScript:
			push_error("BubbleSkinCatalog failed to load skin def: %s" % resource_path)
			continue
		var def := resource as BubbleSkinDef
		if def.bubble_skin_id.is_empty():
			push_error("BubbleSkinCatalog bubble_skin_id is empty: %s" % resource_path)
			continue
		_skins_by_id[def.bubble_skin_id] = def

	for skin_id in _skins_by_id.keys():
		_ordered_ids.append(String(skin_id))
	_ordered_ids.sort()


static func get_by_id(bubble_skin_id: String) -> BubbleSkinDef:
	if _skins_by_id.is_empty():
		load_all()
	if not _skins_by_id.has(bubble_skin_id):
		return null
	return _skins_by_id[bubble_skin_id] as BubbleSkinDef


static func get_all() -> Array[BubbleSkinDef]:
	if _skins_by_id.is_empty():
		load_all()
	var result: Array[BubbleSkinDef] = []
	for bubble_skin_id in _ordered_ids:
		result.append(_skins_by_id[bubble_skin_id] as BubbleSkinDef)
	return result


static func has_id(bubble_skin_id: String) -> bool:
	if _skins_by_id.is_empty():
		load_all()
	return _skins_by_id.has(bubble_skin_id)


static func get_default_skin_id() -> String:
	if _skins_by_id.is_empty():
		load_all()
	if _ordered_ids.is_empty():
		return ""
	return _ordered_ids[0]
