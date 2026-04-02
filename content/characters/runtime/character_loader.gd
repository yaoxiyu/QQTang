class_name CharacterLoader
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")


static func load_character_resource(character_id: String) -> CharacterResource:
	var resolved_character_id := character_id if CharacterCatalogScript.has_character(character_id) else CharacterCatalogScript.get_default_character_id()
	var resource_path := CharacterCatalogScript.get_character_resource_path(resolved_character_id)
	if resource_path.is_empty():
		push_error("CharacterLoader.load_character_resource failed: missing resource path for character_id=%s" % resolved_character_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterResource:
		push_error("CharacterLoader.load_character_resource failed: invalid resource path=%s" % resource_path)
		return null
	return resource


static func load_character_metadata(character_id: String) -> Dictionary:
	return CharacterCatalogScript.get_character_metadata(character_id)


static func build_character_loadout(character_id: String, peer_id: int) -> Dictionary:
	var resource := load_character_resource(character_id)
	if resource == null:
		return {
			"peer_id": peer_id,
			"character_id": "",
		}
	return resource.to_loadout(peer_id)
