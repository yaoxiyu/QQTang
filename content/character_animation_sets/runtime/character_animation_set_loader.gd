class_name CharacterAnimationSetLoader
extends RefCounted

const CharacterAnimationSetCatalogScript = preload("res://content/character_animation_sets/catalog/character_animation_set_catalog.gd")


static func load_animation_set(animation_set_id: String) -> CharacterAnimationSetDef:
	if animation_set_id.is_empty():
		return null
	var animation_set := CharacterAnimationSetCatalogScript.get_by_id(animation_set_id)
	if animation_set == null:
		push_error("CharacterAnimationSetLoader.load_animation_set failed: missing CharacterAnimationSetDef for %s" % animation_set_id)
	return animation_set


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
		"pivot": animation_set.pivot,
		"loop_run": animation_set.loop_run,
		"loop_idle": animation_set.loop_idle,
		"content_hash": animation_set.content_hash,
	}
