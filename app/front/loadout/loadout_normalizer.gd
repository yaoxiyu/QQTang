class_name LoadoutNormalizer
extends RefCounted

const LoadoutResolutionResultScript = preload("res://app/front/loadout/loadout_resolution_result.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")

const ROOM_RANDOM_CHARACTER_ID := "12301"


static func resolve_from_profile(profile):
	var character_id := ""
	var bubble_style_id := ""
	var owned_character_ids: Array[String] = []
	var owned_bubble_style_ids: Array[String] = []
	if profile != null:
		character_id = PlayerProfileState.resolve_default_character_id(String(profile.default_character_id))
		bubble_style_id = String(profile.default_bubble_style_id)
		owned_character_ids = _safe_string_array(profile, "owned_character_ids")
		owned_bubble_style_ids = _safe_string_array(profile, "owned_bubble_style_ids")
	return resolve_ids(
		character_id,
		bubble_style_id,
		owned_character_ids,
		owned_bubble_style_ids
	)


static func resolve_ids(
	character_id: String,
	bubble_style_id: String = "",
	owned_character_ids: Array[String] = [],
	owned_bubble_style_ids: Array[String] = []
):
	var result = LoadoutResolutionResultScript.new()
	var requested_character_id := character_id.strip_edges()
	result.character_id = _resolve_character_id(requested_character_id, owned_character_ids)
	if result.character_id != requested_character_id:
		result.mark_changed("character_id")

	var requested_bubble_style_id := bubble_style_id.strip_edges()
	result.bubble_style_id = _resolve_bubble_style_id(requested_bubble_style_id, result.character_id, owned_bubble_style_ids)
	if result.bubble_style_id != requested_bubble_style_id:
		result.mark_changed("bubble_style_id")
	return result


static func apply_to_ticket_request(request, profile):
	var result = resolve_from_profile(profile)
	if request != null:
		request.selected_character_id = result.character_id
		request.selected_bubble_style_id = result.bubble_style_id
	return result


static func apply_to_connection_config(config, profile):
	var result = resolve_from_profile(profile)
	if config != null:
		config.selected_character_id = result.character_id
		config.selected_bubble_style_id = result.bubble_style_id
	return result


static func _resolve_character_id(character_id: String, owned_character_ids: Array[String]) -> String:
	if character_id == ROOM_RANDOM_CHARACTER_ID and CharacterCatalogScript.has_character(character_id):
		return character_id
	if CharacterCatalogScript.has_character(character_id) and _is_allowed(character_id, owned_character_ids):
		return character_id
	for owned_id in owned_character_ids:
		if CharacterCatalogScript.has_character(owned_id):
			return owned_id
	return CharacterCatalogScript.get_default_character_id()


static func _resolve_bubble_style_id(bubble_style_id: String, character_id: String, owned_bubble_style_ids: Array[String]) -> String:
	if BubbleCatalogScript.has_bubble(bubble_style_id) and _is_allowed(bubble_style_id, owned_bubble_style_ids):
		return bubble_style_id
	for owned_id in owned_bubble_style_ids:
		if BubbleCatalogScript.has_bubble(owned_id):
			return owned_id
	var metadata := CharacterLoaderScript.build_character_metadata(character_id)
	var character_default_bubble_id := String(metadata.get("default_bubble_style_id", ""))
	if BubbleCatalogScript.has_bubble(character_default_bubble_id) and _is_allowed(character_default_bubble_id, owned_bubble_style_ids):
		return character_default_bubble_id
	return BubbleCatalogScript.get_default_bubble_id()


static func _is_allowed(asset_id: String, owned_ids: Array[String]) -> bool:
	return owned_ids.is_empty() or owned_ids.has(asset_id)


static func _safe_string_array(target: Object, property_name: String) -> Array[String]:
	var result: Array[String] = []
	if target == null:
		return result
	for entry in target.get_property_list():
		if String(entry.get("name", "")) != property_name:
			continue
		var value = target.get(property_name)
		if value is Array:
			for item in value:
				result.append(String(item))
		return result
	return result
