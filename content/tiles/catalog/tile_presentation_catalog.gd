class_name TilePresentationCatalog
extends RefCounted

const TilePresentationDefScript = preload("res://content/tiles/defs/tile_presentation_def.gd")
const DATA_DIR := "res://content/tiles/data/presentation"

static var _presentations_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_presentations_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("TilePresentationCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is TilePresentationDefScript:
			push_error("TilePresentationCatalog failed to load TilePresentationDef: %s" % resource_path)
			continue
		var def := resource as TilePresentationDef
		if def.presentation_id.is_empty():
			push_error("TilePresentationCatalog presentation_id is empty: %s" % resource_path)
			continue
		if _presentations_by_id.has(def.presentation_id):
			push_error("TilePresentationCatalog duplicate presentation_id: %s" % def.presentation_id)
			continue
		_presentations_by_id[def.presentation_id] = def

	for presentation_id in _presentations_by_id.keys():
		_ordered_ids.append(String(presentation_id))
	_ordered_ids.sort()


static func get_by_id(presentation_id: String) -> TilePresentationDef:
	if _presentations_by_id.is_empty():
		load_all()
	if not _presentations_by_id.has(presentation_id):
		return null
	return _presentations_by_id[presentation_id] as TilePresentationDef


static func get_all() -> Array[TilePresentationDef]:
	if _presentations_by_id.is_empty():
		load_all()
	var result: Array[TilePresentationDef] = []
	for presentation_id in _ordered_ids:
		result.append(_presentations_by_id[presentation_id] as TilePresentationDef)
	return result


static func has_id(presentation_id: String) -> bool:
	if _presentations_by_id.is_empty():
		load_all()
	return _presentations_by_id.has(presentation_id)
