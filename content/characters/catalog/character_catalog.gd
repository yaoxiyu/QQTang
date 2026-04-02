class_name CharacterCatalog
extends RefCounted

const CHARACTER_REGISTRY := {
	"hero_default": {
		"display_name": "Default Hero",
		"resource_path": "res://content/characters/resources/default_hero.tres",
		"is_default": true,
	},
	"hero_runner": {
		"display_name": "Runner Hero",
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
