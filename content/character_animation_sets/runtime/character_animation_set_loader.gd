class_name CharacterAnimationSetLoader
extends RefCounted

const CharacterAnimationSetCatalogScript = preload("res://content/character_animation_sets/catalog/character_animation_set_catalog.gd")
const CharacterAnimationStripLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_strip_loader.gd")

static var _runtime_cache: Dictionary = {}


static func load_animation_set(animation_set_id: String) -> CharacterAnimationSetDef:
	if animation_set_id.is_empty():
		return null
	if _runtime_cache.has(animation_set_id):
		return _runtime_cache[animation_set_id] as CharacterAnimationSetDef
	var animation_set := CharacterAnimationStripLoaderScript.load_animation_set(animation_set_id)
	if animation_set != null:
		_runtime_cache[animation_set_id] = animation_set
		return animation_set
	animation_set = CharacterAnimationSetCatalogScript.get_by_id(animation_set_id)
	if animation_set == null:
		push_error("CharacterAnimationSetLoader.load_animation_set failed: missing CharacterAnimationSetDef for %s" % animation_set_id)
	return animation_set


static func can_load_animation_set(animation_set_id: String) -> bool:
	if animation_set_id.is_empty():
		return false
	if _runtime_cache.has(animation_set_id):
		return true
	if CharacterAnimationStripLoaderScript.can_load(animation_set_id):
		return true
	return CharacterAnimationSetCatalogScript.has_id(animation_set_id)


static func build_animation_metadata(animation_set_id: String) -> Dictionary:
	var animation_set := load_animation_set(animation_set_id)
	if animation_set == null:
		return {}
	return {
		"animation_set_id": animation_set.animation_set_id,
		"display_name": animation_set.display_name,
		"frame_width": animation_set.frame_width,
		"frame_height": animation_set.frame_height,
		"frames_per_direction": animation_set.frames_per_direction,
		"run_fps": animation_set.run_fps,
		"idle_frame_index": animation_set.idle_frame_index,
		"pivot_origin": animation_set.pivot_origin,
		"pivot_adjust": animation_set.pivot_adjust,
		"pivot": animation_set.pivot,
		"loop_run": animation_set.loop_run,
		"loop_idle": animation_set.loop_idle,
		"content_hash": animation_set.content_hash,
	}
