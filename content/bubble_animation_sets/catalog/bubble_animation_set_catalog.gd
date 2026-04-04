class_name BubbleAnimationSetCatalog
extends RefCounted

const BubbleAnimationSetDefScript = preload("res://content/bubble_animation_sets/defs/bubble_animation_set_def.gd")
const DATA_DIR := "res://content/bubble_animation_sets/data/sets"

static var _animation_sets_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_animation_sets_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("BubbleAnimationSetCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is BubbleAnimationSetDefScript:
			push_error("BubbleAnimationSetCatalog failed to load animation set def: %s" % resource_path)
			continue
		var def := resource as BubbleAnimationSetDef
		if def.animation_set_id.is_empty():
			push_error("BubbleAnimationSetCatalog animation_set_id is empty: %s" % resource_path)
			continue
		if _animation_sets_by_id.has(def.animation_set_id):
			push_error("BubbleAnimationSetCatalog duplicate animation_set_id: %s" % def.animation_set_id)
			continue
		_animation_sets_by_id[def.animation_set_id] = def

	for animation_set_id in _animation_sets_by_id.keys():
		_ordered_ids.append(String(animation_set_id))
	_ordered_ids.sort()


static func get_by_id(animation_set_id: String) -> BubbleAnimationSetDef:
	if _animation_sets_by_id.is_empty():
		load_all()
	if not _animation_sets_by_id.has(animation_set_id):
		return null
	return _animation_sets_by_id[animation_set_id] as BubbleAnimationSetDef


static func get_all() -> Array[BubbleAnimationSetDef]:
	if _animation_sets_by_id.is_empty():
		load_all()
	var result: Array[BubbleAnimationSetDef] = []
	for animation_set_id in _ordered_ids:
		result.append(_animation_sets_by_id[animation_set_id] as BubbleAnimationSetDef)
	return result


static func has_id(animation_set_id: String) -> bool:
	if _animation_sets_by_id.is_empty():
		load_all()
	return _animation_sets_by_id.has(animation_set_id)
