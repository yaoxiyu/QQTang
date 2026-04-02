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
		entries.append({
			"id": character_id,
			"display_name": String(entry.get("display_name", character_id)),
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
