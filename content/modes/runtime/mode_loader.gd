class_name ModeLoader
extends RefCounted

const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const ModeDefScript = preload("res://content/modes/defs/mode_def.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")


static func load_mode_def(mode_id: String) -> ModeDef:
	var resolved_mode_id := mode_id if ModeCatalogScript.has_mode(mode_id) else ModeCatalogScript.get_default_mode_id()
	var resource_path := ModeCatalogScript.get_mode_resource_path(resolved_mode_id)
	if resource_path.is_empty():
		push_error("ModeLoader.load_mode_def failed: missing resource path for mode_id=%s" % resolved_mode_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is ModeDefScript:
		push_error("ModeLoader.load_mode_def failed: invalid resource path=%s" % resource_path)
		return null
	return resource


static func load_metadata(mode_id: String) -> Dictionary:
	var mode_def := load_mode_def(mode_id)
	if mode_def == null:
		return {}
	var metadata := {
		"mode_id": mode_def.mode_id,
		"display_name": mode_def.display_name,
		"rule_set_id": mode_def.rule_set_id,
		"default_map_id": mode_def.default_map_id,
		"min_player_count": mode_def.min_player_count,
		"max_player_count": mode_def.max_player_count,
		"allow_character_select": mode_def.allow_character_select,
		"allow_bubble_select": mode_def.allow_bubble_select,
		"allow_map_select": mode_def.allow_map_select,
		"hud_layout_id": mode_def.hud_layout_id,
		"content_hash": mode_def.content_hash,
	}
	var rule_metadata := RuleSetCatalogScript.get_rule_metadata(String(metadata.get("rule_set_id", "")))
	if not rule_metadata.is_empty():
		metadata["rule_display_name"] = String(rule_metadata.get("display_name", ""))
	var map_metadata := MapCatalogScript.get_map_metadata(String(metadata.get("default_map_id", "")))
	if not map_metadata.is_empty():
		metadata["default_map_display_name"] = String(map_metadata.get("display_name", ""))
	return metadata
