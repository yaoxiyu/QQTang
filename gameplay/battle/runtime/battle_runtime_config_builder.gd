extends RefCounted
class_name BattleRuntimeConfigBuilder

const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const ModeLoaderScript = preload("res://content/modes/runtime/mode_loader.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const MapThemeCatalogScript = preload("res://content/map_themes/catalog/map_theme_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

const MAP_DATA_DIR := "res://content/maps/data/map"

var _last_errors: PackedStringArray = []


func build(room_selection_state: RoomSelectionState) -> BattleRuntimeConfig:
	_last_errors = PackedStringArray()
	if room_selection_state == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: room_selection_state is null")

	var mode_id := String(room_selection_state.mode_id)
	if mode_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: room_selection_state.mode_id is empty")
	var mode_config := ModeLoaderScript.load_mode_def(mode_id)
	if mode_config == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load mode: %s" % mode_id)

	var rule_set_id := String(mode_config.rule_set_id)
	if rule_set_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: mode.rule_set_id is empty for mode=%s" % mode_id)
	var rule_config := RuleSetCatalogScript.get_by_id(rule_set_id)
	if rule_config == null:
		return _fail_with("BattleRuntimeConfigBuilder.build: failed to load RuleSetDef: %s" % rule_set_id)

	var map_id := String(room_selection_state.map_id)
	if map_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder.build: room_selection_state.map_id is empty")
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
	var character_id := String(state.get("character_id", ""))
	if character_id.is_empty():
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: character_id is empty for peer=%d" % peer_id)

	var character_stats := CharacterLoaderScript.load_character_stats(character_id)
	if character_stats == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterStatsDef for peer=%d, character=%s" % [peer_id, character_id])

	var character_presentation := CharacterLoaderScript.load_character_presentation(character_id)
	if character_presentation == null:
		return _fail_with("BattleRuntimeConfigBuilder._build_player_config: failed to load CharacterPresentationDef for peer=%d, character=%s" % [peer_id, character_id])

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
		push_error("BattleRuntimeConfigBuilder._load_map_def: invalid MapDef resource: %s" % resource_path)
	var map_resource := MapLoaderScript.load_map_resource(map_id)
	if map_resource == null:
		push_error("BattleRuntimeConfigBuilder._load_map_def: missing map resource: %s" % resource_path)
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
	push_error(message)
	return null
