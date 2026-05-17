class_name CharacterLoader
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const CharacterDefScript = preload("res://content/characters/defs/character_def.gd")
const CharacterStatsDefScript = preload("res://content/characters/defs/character_stats_def.gd")
const CharacterPresentationDefScript = preload("res://content/characters/defs/character_presentation_def.gd")


static func load_character_metadata(character_id: String) -> Dictionary:
	return build_character_metadata(character_id)


static func load_character_def(character_id: String) -> CharacterDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("def_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterDefScript:
		return resource
	push_error("CharacterLoader.load_character_def failed: missing CharacterDef for %s" % resolved_character_id)
	return null


static func load_character_stats(character_id: String) -> CharacterStatsDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("stats_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterStatsDefScript:
		return resource
	push_error("CharacterLoader.load_character_stats failed: missing CharacterStatsDef for %s" % resolved_character_id)
	return null


static func load_character_presentation(character_id: String) -> CharacterPresentationDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("presentation_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterPresentationDefScript:
		return resource
	push_error("CharacterLoader.load_character_presentation failed: missing CharacterPresentationDef for %s" % resolved_character_id)
	return null


static func build_character_metadata(character_id: String) -> Dictionary:
	var resolved_character_id := _resolve_character_id(character_id)
	var character_def := load_character_def(resolved_character_id)
	var stats_def := load_character_stats(resolved_character_id)
	var presentation_def := load_character_presentation(resolved_character_id)
	if character_def == null or stats_def == null or presentation_def == null:
		return {}
	var entry := _get_character_registry_entry(resolved_character_id)
	var display_name := String(character_def.display_name if not character_def.display_name.is_empty() else presentation_def.display_name)
	if display_name.is_empty():
		display_name = String(entry.get("display_name", resolved_character_id))
	var default_bubble_style_id := String(character_def.default_bubble_style_id)
	if default_bubble_style_id.is_empty():
		default_bubble_style_id = BubbleCatalogScript.get_default_bubble_id()
	return {
		"id": resolved_character_id,
		"character_id": String(character_def.character_id if not character_def.character_id.is_empty() else resolved_character_id),
		"display_name": display_name,
		"chinese_name": String(character_def.chinese_name if not character_def.chinese_name.is_empty() else display_name),
		"gender": String(character_def.gender if not character_def.gender.is_empty() else "male").to_lower(),
		"version": 1,
		"content_hash": _resolve_content_hash(
			resolved_character_id,
			character_def.content_hash,
			stats_def.content_hash,
			presentation_def.content_hash
		),
		"stats_id": stats_def.stats_id,
		"presentation_id": presentation_def.presentation_id,
		"default_bubble_style_id": default_bubble_style_id,
		"selection_order": character_def.selection_order,
		"type": character_def.type,
		"selection_portrait_path": character_def.selection_portrait_path,
		"base_bomb_count": stats_def.base_bomb_count,
		"base_firepower": stats_def.base_firepower,
		"base_move_speed": stats_def.base_move_speed,
		"initial_bubble_count": stats_def.initial_bubble_count,
		"max_bubble_count": stats_def.max_bubble_count,
		"initial_bubble_power": stats_def.initial_bubble_power,
		"max_bubble_power": stats_def.max_bubble_power,
		"initial_move_speed": stats_def.initial_move_speed,
		"max_move_speed": stats_def.max_move_speed,
		"actor_scene_path": presentation_def.actor_scene_path,
		"portrait_small_path": presentation_def.portrait_small_path,
		"portrait_large_path": presentation_def.portrait_large_path,
		"hud_icon_path": presentation_def.hud_icon_path,
		"spawn_fx_id": presentation_def.spawn_fx_id,
		"victory_fx_id": presentation_def.victory_fx_id,
	}


static func build_character_loadout(character_id: String, peer_id: int) -> Dictionary:
	var metadata := build_character_metadata(character_id)
	if metadata.is_empty():
		return {
			"peer_id": peer_id,
			"character_id": "",
		}
	return {
		"peer_id": peer_id,
		"character_id": String(metadata.get("character_id", "")),
		"display_name": String(metadata.get("display_name", "")),
		"base_bomb_count": int(metadata.get("base_bomb_count", 1)),
		"base_firepower": int(metadata.get("base_firepower", 1)),
		"base_move_speed": int(metadata.get("base_move_speed", 1)),
		"initial_bubble_count": int(metadata.get("initial_bubble_count", metadata.get("base_bomb_count", 1))),
		"max_bubble_count": int(metadata.get("max_bubble_count", 5)),
		"initial_bubble_power": int(metadata.get("initial_bubble_power", metadata.get("base_firepower", 1))),
		"max_bubble_power": int(metadata.get("max_bubble_power", 5)),
		"initial_move_speed": int(metadata.get("initial_move_speed", metadata.get("base_move_speed", 1))),
		"max_move_speed": int(metadata.get("max_move_speed", 9)),
		"content_hash": String(metadata.get("content_hash", "")),
	}


static func _resolve_character_id(character_id: String) -> String:
	return character_id if CharacterCatalogScript.has_character(character_id) else CharacterCatalogScript.get_default_character_id()


static func _get_character_registry_entry(character_id: String) -> Dictionary:
	return CharacterCatalogScript.get_character_entry(character_id)


static func _load_resource(resource_path: String) -> Resource:
	if resource_path.is_empty():
		return null
	return load(resource_path)


static func _resolve_content_hash(character_id: String, primary_hash: String, secondary_hash: String, tertiary_hash: String) -> String:
	if not primary_hash.is_empty():
		return primary_hash
	if not secondary_hash.is_empty():
		return secondary_hash
	if not tertiary_hash.is_empty():
		return tertiary_hash
	return "character_%s_fallback_v1" % character_id
