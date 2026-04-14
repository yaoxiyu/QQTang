class_name RoomSelectionPolicy
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")


static func resolve_request_loadout(message: Dictionary, ticket_verifier = null, ticket_claim = null) -> Dictionary:
	var character_id := String(message.get("character_id", "")).strip_edges()
	if character_id.is_empty() or not CharacterCatalogScript.has_character(character_id):
		return _fail("ROOM_MEMBER_PROFILE_INVALID", "Character selection is invalid")
	var resolved := normalize_member_loadout(
		character_id,
		String(message.get("character_skin_id", "")),
		String(message.get("bubble_style_id", "")),
		String(message.get("bubble_skin_id", ""))
	)
	if ticket_verifier != null and ticket_verifier.has_method("is_loadout_allowed"):
		if not ticket_verifier.is_loadout_allowed(
			ticket_claim,
			String(resolved.get("character_id", "")),
			String(resolved.get("character_skin_id", "")),
			String(resolved.get("bubble_style_id", "")),
			String(resolved.get("bubble_skin_id", ""))
		):
			return _fail("ROOM_TICKET_LOADOUT_FORBIDDEN", "Requested loadout is not allowed by room ticket")
	resolved["ok"] = true
	return resolved


static func normalize_member_loadout(
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = ""
) -> Dictionary:
	var resolved_character_id := _resolve_character_id(character_id)
	return {
		"character_id": resolved_character_id,
		"character_skin_id": _resolve_character_skin_id(character_skin_id),
		"bubble_style_id": _resolve_bubble_style_id(bubble_style_id, resolved_character_id),
		"bubble_skin_id": _resolve_bubble_skin_id(bubble_skin_id),
	}


static func _resolve_character_id(character_id: String) -> String:
	var trimmed := character_id.strip_edges()
	if CharacterCatalogScript.has_character(trimmed):
		return trimmed
	return CharacterCatalogScript.get_default_character_id()


static func _resolve_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if CharacterSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


static func _resolve_bubble_style_id(bubble_style_id: String, character_id: String) -> String:
	var trimmed := bubble_style_id.strip_edges()
	if BubbleCatalogScript.has_bubble(trimmed):
		return trimmed
	var metadata := CharacterLoaderScript.build_character_metadata(character_id)
	var default_bubble_style_id := String(metadata.get("default_bubble_style_id", ""))
	if BubbleCatalogScript.has_bubble(default_bubble_style_id):
		return default_bubble_style_id
	return BubbleCatalogScript.get_default_bubble_id()


static func _resolve_bubble_skin_id(bubble_skin_id: String) -> String:
	var trimmed := bubble_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if BubbleSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


static func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"user_message": user_message,
	}
