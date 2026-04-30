class_name VfxAnimationSetCatalog
extends RefCounted

const VfxAnimationSetDefScript = preload("res://content/vfx_animation_sets/defs/vfx_animation_set_def.gd")
const DATA_DIR := "res://content/vfx_animation_sets/data/sets"

static var _sets_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_sets_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("VfxAnimationSetCatalog data dir missing: %s" % DATA_DIR)
		return
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is VfxAnimationSetDefScript:
			push_error("VfxAnimationSetCatalog failed to load vfx def: %s" % resource_path)
			continue
		var def := resource
		if def.vfx_set_id.is_empty():
			push_error("VfxAnimationSetCatalog vfx_set_id is empty: %s" % resource_path)
			continue
		if _sets_by_id.has(def.vfx_set_id):
			push_error("VfxAnimationSetCatalog duplicate vfx_set_id: %s" % def.vfx_set_id)
			continue
		_sets_by_id[def.vfx_set_id] = def
	for vfx_set_id in _sets_by_id.keys():
		_ordered_ids.append(String(vfx_set_id))
	_ordered_ids.sort()


static func get_by_id(vfx_set_id: String) -> Resource:
	if _sets_by_id.is_empty():
		load_all()
	if not _sets_by_id.has(vfx_set_id):
		return null
	return _sets_by_id[vfx_set_id] as Resource


static func has_id(vfx_set_id: String) -> bool:
	if _sets_by_id.is_empty():
		load_all()
	return _sets_by_id.has(vfx_set_id)

