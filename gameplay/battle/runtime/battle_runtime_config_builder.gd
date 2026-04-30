extends RefCounted
class_name BattleRuntimeConfigBuilder

const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const ModeLoaderScript = preload("res://content/modes/runtime/mode_loader.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const MapThemeCatalogScript = preload("res://content/map_themes/catalog/map_theme_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const LogBattleScript = preload("res://app/logging/log_battle.gd")

const MAP_DATA_DIR := "res://content/maps/data/map"

var _last_errors: PackedStringArray = []


func build(room_selection_state: RoomSelectionState) -> BattleRuntimeConfig:
	_last_errors = PackedStringArray()
	if room_selection_state == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: room_selection_state is null")

	var mode_id := String(room_selection_state.mode_id)
	var map_id := String(room_selection_state.map_id)
	if map_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: room_selection_state.map_id is empty")
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return _fail_with("BattleRuntimeConfigBuilder.build: invalid map binding for map=%s" % map_id)
	var authoritative_mode_id := String(binding.get("bound_mode_id", mode_id))
	var authoritative_rule_set_id := String(binding.get("bound_rule_set_id", ""))
	if authoritative_mode_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: authoritative mode_id is empty for map=%s" % map_id)
	var mode_config := ModeLoaderScript.load_mode_def(mode_id)
	if authoritative_mode_id != mode_id and not mode_id.is_empty():
		LogBattleScript.warn(
			"BattleRuntimeConfigBuilder.build: mode mismatch map=%s snapshot=%s authoritative=%s" % [
				map_id,
				mode_id,
				authoritative_mode_id,
			],
			"",
			0,
			"battle.runtime.config"
		)
	mode_config = ModeLoaderScript.load_mode_def(authoritative_mode_id)
	if mode_config == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load mode: %s" % authoritative_mode_id)

	var rule_set_id := authoritative_rule_set_id
	if rule_set_id.is_empty():
		rule_set_id = String(mode_config.rule_set_id)
	if rule_set_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: authoritative rule_set_id is empty for map=%s" % map_id)
	if authoritative_rule_set_id != String(room_selection_state.rule_set_id) and not String(room_selection_state.rule_set_id).is_empty():
		LogBattleScript.warn(
			"BattleRuntimeConfigBuilder.build: rule mismatch map=%s snapshot=%s authoritative=%s" % [
				map_id,
				String(room_selection_state.rule_set_id),
				authoritative_rule_set_id,
			],
			"",
			0,
			"battle.runtime.config"
		)
	var rule_config := RuleSetCatalogScript.get_by_id(rule_set_id)
	if rule_config == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load RuleSetDef: %s" % rule_set_id)

	var map_config := _load_map_def(map_id)
	if map_config == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load MapDef: %s" % map_id)

	var theme_id := String(map_config.theme_id)
	if theme_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: map.theme_id is empty for map=%s" % map_id)
	var map_theme := MapThemeCatalogScript.get_by_id(theme_id)
	if map_theme == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load MapThemeDef: %s" % theme_id)

	var player_configs: Array[PlayerRuntimeConfig] = []
	var player_ids: Array = room_selection_state.players.keys()
	player_ids.sort()
	for peer_id_variant in player_ids:
		var player_state : Dictionary = room_selection_state.players[peer_id_variant]
		var player_config := _build_player_config(player_state, int(peer_id_variant))
		if player_config == null:
			return null
		player_configs.append(player_config)

	var runtime_config := BattleRuntimeConfig.new()
	runtime_config.mode_config = mode_config
	runtime_config.rule_config = rule_config
	runtime_config.map_config = map_config
	runtime_config.map_theme = map_theme
	runtime_config.player_configs = player_configs
	return runtime_config


func get_last_errors() -> PackedStringArray:
	return _last_errors


func _build_player_config(player_state: Variant, peer_id: int) -> PlayerRuntimeConfig:
	if not player_state is Dictionary:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: invalid player state for peer=%d" % peer_id)

	var state := player_state as Dictionary
	var slot_index := int(state.get("slot_index", -1))
	var team_id := int(state.get("team_id", 0))
	var character_id := String(state.get("character_id", ""))
	if character_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: character_id is empty for peer=%d" % peer_id)

	var character_stats := CharacterLoaderScript.load_character_stats(character_id)
	if character_stats == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterStatsDef for peer=%d, character=%s" % [peer_id, character_id])

	var character_presentation := CharacterLoaderScript.load_character_presentation(character_id)
	if character_presentation == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterPresentationDef for peer=%d, character=%s" % [peer_id, character_id])
	if character_presentation.body_scene == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: missing body_scene for peer=%d, character=%s" % [peer_id, character_id])
	if String(character_presentation.body_view_type) == "sprite_frames_2d":
		var animation_set_id := String(character_presentation.animation_set_id)
		if animation_set_id.is_empty():
			return _fail_with("BattleRuntimeConfigBuilder._build_player_config: empty animation_set_id for peer=%d, character=%s" % [peer_id, character_id])
		if CharacterAnimationSetLoaderScript.load_animation_set(animation_set_id) == null:
			return _fail_with(
				"BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterAnimationSetDef for peer=%d, character=%s, animation_set_id=%s"
				% [peer_id, character_id, animation_set_id]
			)

	var character_skin_id := String(state.get("character_skin_id", ""))
	var character_skin: CharacterSkinDef = null
	if not character_skin_id.is_empty():
		character_skin = CharacterSkinCatalogScript.get_by_id(character_skin_id)
	if not character_skin_id.is_empty() and character_skin == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterSkinDef for peer=%d, skin=%s" % [peer_id, character_skin_id])

	var bubble_style_id := String(state.get("bubble_style_id", ""))
	if bubble_style_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: bubble_style_id is empty for peer=%d" % peer_id)
	var bubble_style := BubbleLoaderScript.load_style(bubble_style_id)
	if bubble_style == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load BubbleStyleDef for peer=%d, bubble=%s" % [peer_id, bubble_style_id])

	var bubble_gameplay := BubbleLoaderScript.load_gameplay(bubble_style_id)
	if bubble_gameplay == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load BubbleGameplayDef for peer=%d, bubble=%s" % [peer_id, bubble_style_id])

	var bubble_skin_id := String(state.get("bubble_skin_id", ""))
	var bubble_skin: BubbleSkinDef = null
	if not bubble_skin_id.is_empty():
		bubble_skin = BubbleSkinCatalogScript.get_by_id(bubble_skin_id)
	if not bubble_skin_id.is_empty() and bubble_skin == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load BubbleSkinDef for peer=%d, skin=%s" % [peer_id, bubble_skin_id])

	var player_config := PlayerRuntimeConfig.new()
	player_config.peer_id = peer_id
	player_config.player_slot = slot_index
	player_config.team_id = team_id
	player_config.character_id = character_id
	player_config.character_stats = character_stats
	player_config.character_presentation = character_presentation
	player_config.character_skin = character_skin
	player_config.bubble_style = bubble_style
	player_config.bubble_gameplay = bubble_gameplay
	player_config.bubble_skin = bubble_skin
	return player_config


func _load_map_def(map_id: String) -> MapDef:
	var resource_path := "%s/%s.tres" % [MAP_DATA_DIR, map_id]
	if ResourceLoader.exists(resource_path):
		var resource := load(resource_path)
		if resource != null and resource is MapDef:
			return resource as MapDef
		LogBattleScript.error("BattleRuntimeConfigBuilder._load_map_def: invalid MapDef resource: %s" % resource_path, "", 0, "battle.runtime.config")
	var map_resource := MapLoaderScript.load_map_resource(map_id)
	if map_resource == null:
		LogBattleScript.error("BattleRuntimeConfigBuilder._load_map_def: missing map resource: %s" % resource_path, "", 0, "battle.runtime.config")
		return null
	var compat_def := MapDef.new()
	compat_def.map_id = String(map_resource.map_id)
	compat_def.display_name = String(map_resource.display_name)
	compat_def.width = int(map_resource.width)
	compat_def.height = int(map_resource.height)
	compat_def.spawn_points = map_resource.spawn_points.duplicate()
	compat_def.theme_id = String(map_resource.tile_theme_id)
	return compat_def


func _fail_with(message: String):
	_last_errors.append(message)
	LogBattleScript.error(message, "", 0, "battle.runtime.config")
	return null
