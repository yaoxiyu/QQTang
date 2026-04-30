class_name BattlePlayerVisualProfileBuilder
extends RefCounted

const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterTeamAnimationResolverScript = preload("res://content/character_animation_sets/runtime/character_team_animation_resolver.gd")


func build(runtime_config: BattleRuntimeConfig, player_slots: Array[Dictionary] = []) -> Dictionary:
	var result: Dictionary = {}
	if runtime_config == null:
		return result

	for index in range(runtime_config.player_configs.size()):
		var player_config := runtime_config.player_configs[index]
		if player_config == null:
			continue

		var player_slot := _resolve_player_slot(index, player_slots, player_config)
		var profile := BattlePlayerVisualProfile.new()
		profile.player_slot = player_slot
		profile.team_id = _resolve_team_id(index, player_slots, player_config)
		profile.character_id = player_config.character_id
		profile.character_presentation = player_config.character_presentation
		profile.character_skin = player_config.character_skin
		profile.animation_set = _load_animation_set(player_config.character_presentation, profile.team_id)
		result[player_slot] = profile

	return result


func _resolve_player_slot(index: int, player_slots: Array[Dictionary], player_config: PlayerRuntimeConfig = null) -> int:
	if player_config != null and player_config.player_slot >= 0:
		return player_config.player_slot
	if index >= 0 and index < player_slots.size():
		return int(player_slots[index].get("slot_index", index))
	return index


func _resolve_team_id(index: int, player_slots: Array[Dictionary], player_config: PlayerRuntimeConfig = null) -> int:
	if player_config != null and player_config.team_id > 0:
		return player_config.team_id
	if index >= 0 and index < player_slots.size():
		return int(player_slots[index].get("team_id", 0))
	return 0


func _load_animation_set(character_presentation: CharacterPresentationDef, team_id: int = 0) -> CharacterAnimationSetDef:
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
	var resolved_animation_set_id := CharacterTeamAnimationResolverScript.resolve_animation_set_id(animation_set_id, team_id, false)
	var animation_set := CharacterAnimationSetLoaderScript.load_animation_set(resolved_animation_set_id)
	if animation_set == null:
		push_error(
			"BattlePlayerVisualProfileBuilder._load_animation_set failed to load %s for %s"
			% [resolved_animation_set_id, presentation_id]
		)
	return animation_set
