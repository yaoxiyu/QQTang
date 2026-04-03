class_name CharacterCatalog
extends RefCounted

const CharacterDefScript = preload("res://content/characters/resources/character_def.gd")
const CharacterStatsDefScript = preload("res://content/characters/resources/character_stats_def.gd")
const CharacterPresentationDefScript = preload("res://content/characters/resources/character_presentation_def.gd")

const CHARACTER_REGISTRY := {
	"hero_default": {
		"display_name": "Default Hero",
		"def_resource_path": "res://content/characters/resources/hero_default_def.tres",
		"stats_resource_path": "res://content/characters/resources/hero_default_stats.tres",
		"presentation_resource_path": "res://content/characters/resources/hero_default_presentation.tres",
		"resource_path": "res://content/characters/resources/default_hero.tres",
		"is_default": true,
	},
	"hero_runner": {
		"display_name": "Runner Hero",
		"def_resource_path": "res://content/characters/resources/hero_runner_def.tres",
		"stats_resource_path": "res://content/characters/resources/hero_runner_stats.tres",
		"presentation_resource_path": "res://content/characters/resources/hero_runner_presentation.tres",
		"resource_path": "res://content/characters/resources/runner_hero.tres",
	},
}


static func get_character_ids() -> Array[String]:
	var character_ids: Array[String] = []
	for character_id in CHARACTER_REGISTRY.keys():
		character_ids.append(String(character_id))
	character_ids.sort()
	return character_ids


static func get_character_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for character_id in get_character_ids():
		var entry: Dictionary = CHARACTER_REGISTRY[character_id]
		var metadata := get_character_metadata(character_id)
		entries.append({
			"id": character_id,
			"display_name": String(entry.get("display_name", character_id)),
			"version": int(metadata.get("version", 1)),
			"content_hash": String(metadata.get("content_hash", "")),
			"base_bomb_count": int(metadata.get("base_bomb_count", 0)),
			"base_firepower": int(metadata.get("base_firepower", 0)),
			"base_move_speed": int(metadata.get("base_move_speed", 0)),
		})
	return entries


static func has_character(character_id: String) -> bool:
	return CHARACTER_REGISTRY.has(character_id)


static func get_default_character_id() -> String:
	for character_id in get_character_ids():
		if bool(CHARACTER_REGISTRY[character_id].get("is_default", false)):
			return character_id
	var character_ids := get_character_ids()
	if character_ids.is_empty():
		return ""
	return character_ids[0]


static func get_character_resource_path(character_id: String) -> String:
	if not has_character(character_id):
		return ""
	return String(CHARACTER_REGISTRY[character_id].get("resource_path", ""))


static func get_character_metadata(character_id: String) -> Dictionary:
	if not has_character(character_id):
		return {}
	var entry: Dictionary = CHARACTER_REGISTRY[character_id]
	var character_def := _load_character_def(entry)
	var stats_def := _load_character_stats(entry)
	var presentation_def := _load_character_presentation(entry)
	if character_def != null and stats_def != null and presentation_def != null:
		var display_name := String(character_def.display_name if not character_def.display_name.is_empty() else presentation_def.display_name)
		if display_name.is_empty():
			display_name = String(entry.get("display_name", character_id))
		return {
			"id": character_id,
			"character_id": String(character_def.character_id if not character_def.character_id.is_empty() else character_id),
			"display_name": display_name,
			"version": 1,
			"content_hash": _resolve_content_hash(
				character_id,
				character_def.content_hash,
				stats_def.content_hash,
				presentation_def.content_hash
			),
			"base_bomb_count": stats_def.base_bomb_count,
			"base_firepower": stats_def.base_firepower,
			"base_move_speed": stats_def.base_move_speed,
			"stats_id": stats_def.stats_id,
			"presentation_id": presentation_def.presentation_id,
			"default_bubble_style_id": character_def.default_bubble_style_id,
			"selection_portrait_path": character_def.selection_portrait_path,
			"resource_path": get_character_resource_path(character_id),
		}
	var resource_path := get_character_resource_path(character_id)
	if resource_path.is_empty():
		return {}
	var resource := load(resource_path)
	if resource == null or not resource is CharacterResource:
		return {}
	var character_resource := resource as CharacterResource
	return {
		"id": character_id,
		"display_name": character_resource.display_name,
		"version": 1,
		"content_hash": character_resource.content_hash,
		"base_bomb_count": character_resource.base_bomb_count,
		"base_firepower": character_resource.base_firepower,
		"base_move_speed": character_resource.base_move_speed,
		"resource_path": resource_path,
	}


static func _load_character_def(entry: Dictionary) -> CharacterDef:
	var resource_path := String(entry.get("def_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterDefScript:
		return null
	return resource


static func _load_character_stats(entry: Dictionary) -> CharacterStatsDef:
	var resource_path := String(entry.get("stats_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterStatsDefScript:
		return null
	return resource


static func _load_character_presentation(entry: Dictionary) -> CharacterPresentationDef:
	var resource_path := String(entry.get("presentation_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterPresentationDefScript:
		return null
	return resource


static func _resolve_content_hash(character_id: String, primary_hash: String, secondary_hash: String, tertiary_hash: String) -> String:
	if not primary_hash.is_empty():
		return primary_hash
	if not secondary_hash.is_empty():
		return secondary_hash
	if not tertiary_hash.is_empty():
		return tertiary_hash
	return "character_%s_fallback_v1" % character_id
