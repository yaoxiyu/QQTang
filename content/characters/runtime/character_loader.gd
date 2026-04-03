class_name CharacterLoader
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterDefScript = preload("res://content/characters/resources/character_def.gd")
const CharacterStatsDefScript = preload("res://content/characters/resources/character_stats_def.gd")
const CharacterPresentationDefScript = preload("res://content/characters/resources/character_presentation_def.gd")


static func load_character_resource(character_id: String) -> CharacterResource:
	var resolved_character_id := character_id if CharacterCatalogScript.has_character(character_id) else CharacterCatalogScript.get_default_character_id()
	var resource_path := CharacterCatalogScript.get_character_resource_path(resolved_character_id)
	if not resource_path.is_empty():
		var resource := load(resource_path)
		if resource != null and resource is CharacterResource:
			return resource
	var metadata := build_character_metadata(resolved_character_id)
	if metadata.is_empty():
		push_error("CharacterLoader.load_character_resource failed: unable to resolve character_id=%s" % resolved_character_id)
		return null
	var synthesized_resource := CharacterResource.new()
	synthesized_resource.character_id = String(metadata.get("character_id", resolved_character_id))
	synthesized_resource.display_name = String(metadata.get("display_name", resolved_character_id))
	synthesized_resource.base_bomb_count = int(metadata.get("base_bomb_count", 1))
	synthesized_resource.base_firepower = int(metadata.get("base_firepower", 1))
	synthesized_resource.base_move_speed = int(metadata.get("base_move_speed", 1))
	synthesized_resource.content_hash = String(metadata.get("content_hash", ""))
	return synthesized_resource


static func load_character_metadata(character_id: String) -> Dictionary:
	return build_character_metadata(character_id)


static func load_character_def(character_id: String) -> CharacterDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("def_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterDefScript:
		return resource
	var legacy_resource := load_character_resource(resolved_character_id)
	if legacy_resource == null:
		return null
	var character_def := CharacterDef.new()
	character_def.character_id = legacy_resource.character_id
	character_def.display_name = legacy_resource.display_name
	character_def.content_hash = legacy_resource.content_hash
	return character_def


static func load_character_stats(character_id: String) -> CharacterStatsDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("stats_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterStatsDefScript:
		return resource
	var legacy_resource := load_character_resource(resolved_character_id)
	if legacy_resource == null:
		return null
	var stats_def := CharacterStatsDef.new()
	stats_def.stats_id = "legacy_%s" % resolved_character_id
	stats_def.base_bomb_count = legacy_resource.base_bomb_count
	stats_def.base_firepower = legacy_resource.base_firepower
	stats_def.base_move_speed = legacy_resource.base_move_speed
	stats_def.content_hash = legacy_resource.content_hash
	return stats_def


static func load_character_presentation(character_id: String) -> CharacterPresentationDef:
	var resolved_character_id := _resolve_character_id(character_id)
	var entry := _get_character_registry_entry(resolved_character_id)
	var resource_path := String(entry.get("presentation_resource_path", ""))
	var resource := _load_resource(resource_path)
	if resource != null and resource is CharacterPresentationDefScript:
		return resource
	var legacy_resource := load_character_resource(resolved_character_id)
	if legacy_resource == null:
		return null
	var presentation_def := CharacterPresentationDef.new()
	presentation_def.presentation_id = "legacy_%s" % resolved_character_id
	presentation_def.display_name = legacy_resource.display_name
	presentation_def.content_hash = legacy_resource.content_hash
	return presentation_def


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
		default_bubble_style_id = "bubble_default"
	return {
		"id": resolved_character_id,
		"character_id": String(character_def.character_id if not character_def.character_id.is_empty() else resolved_character_id),
		"display_name": display_name,
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
		"selection_portrait_path": character_def.selection_portrait_path,
		"base_bomb_count": stats_def.base_bomb_count,
		"base_firepower": stats_def.base_firepower,
		"base_move_speed": stats_def.base_move_speed,
		"actor_scene_path": presentation_def.actor_scene_path,
		"portrait_small_path": presentation_def.portrait_small_path,
		"portrait_large_path": presentation_def.portrait_large_path,
		"hud_icon_path": presentation_def.hud_icon_path,
		"spawn_fx_id": presentation_def.spawn_fx_id,
		"victory_fx_id": presentation_def.victory_fx_id,
		"resource_path": CharacterCatalogScript.get_character_resource_path(resolved_character_id),
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
		"content_hash": String(metadata.get("content_hash", "")),
	}


static func _resolve_character_id(character_id: String) -> String:
	return character_id if CharacterCatalogScript.has_character(character_id) else CharacterCatalogScript.get_default_character_id()


static func _get_character_registry_entry(character_id: String) -> Dictionary:
	if not CharacterCatalogScript.has_character(character_id):
		return {}
	return CharacterCatalogScript.CHARACTER_REGISTRY[character_id]


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
