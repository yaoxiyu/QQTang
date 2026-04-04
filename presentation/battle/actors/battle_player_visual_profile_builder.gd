class_name BattlePlayerVisualProfileBuilder
extends RefCounted

const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")


func build(runtime_config: BattleRuntimeConfig, player_slots: Array[Dictionary] = []) -> Dictionary:
	var result: Dictionary = {}
	if runtime_config == null:
		return result

	for index in range(runtime_config.player_configs.size()):
		var player_config := runtime_config.player_configs[index]
		if player_config == null:
			continue

		var player_slot := _resolve_player_slot(index, player_slots)
		var profile := BattlePlayerVisualProfile.new()
		profile.player_slot = player_slot
		profile.character_id = player_config.character_id
		profile.character_presentation = player_config.character_presentation
		profile.character_skin = player_config.character_skin
		profile.animation_set = _load_animation_set(player_config.character_presentation)
		result[player_slot] = profile

	return result


func _resolve_player_slot(index: int, player_slots: Array[Dictionary]) -> int:
	if index >= 0 and index < player_slots.size():
		return int(player_slots[index].get("slot_index", index))
	return index


func _load_animation_set(character_presentation: CharacterPresentationDef) -> CharacterAnimationSetDef:
	if character_presentation == null:
		return null
	var presentation_id := String(character_presentation.presentation_id)
	var body_view_type := String(character_presentation.body_view_type)
	if body_view_type != "sprite_frames_2d":
		push_error(
			"BattlePlayerVisualProfileBuilder._load_animation_set unsupported body_view_type for %s: %s"
			% [presentation_id, body_view_type]
		)
		return null
	var animation_set_id := String(character_presentation.animation_set_id)
	if animation_set_id.is_empty():
		push_error(
			"BattlePlayerVisualProfileBuilder._load_animation_set empty animation_set_id for %s"
			% presentation_id
		)
		return null
	var animation_set := CharacterAnimationSetLoaderScript.load_animation_set(animation_set_id)
	if animation_set == null:
		push_error(
			"BattlePlayerVisualProfileBuilder._load_animation_set failed to load %s for %s"
			% [animation_set_id, presentation_id]
		)
	return animation_set
