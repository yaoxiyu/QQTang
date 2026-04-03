class_name BattleModeContentBuilder
extends RefCounted

const ModeLoaderScript = preload("res://content/modes/runtime/mode_loader.gd")


func build_for_mode_id(mode_id: String) -> Dictionary:
	var metadata := ModeLoaderScript.load_metadata(mode_id)
	if metadata.is_empty():
		return {}
	return {
		"mode_id": String(metadata.get("mode_id", mode_id)),
		"display_name": String(metadata.get("display_name", "")),
		"rule_set_id": String(metadata.get("rule_set_id", "")),
		"default_map_id": String(metadata.get("default_map_id", "")),
		"min_player_count": int(metadata.get("min_player_count", 1)),
		"max_player_count": int(metadata.get("max_player_count", 4)),
		"allow_character_select": bool(metadata.get("allow_character_select", true)),
		"allow_bubble_select": bool(metadata.get("allow_bubble_select", true)),
		"allow_map_select": bool(metadata.get("allow_map_select", true)),
		"hud_layout_id": String(metadata.get("hud_layout_id", "default")),
		"content_hash": String(metadata.get("content_hash", "")),
		"rule_display_name": String(metadata.get("rule_display_name", "")),
		"default_map_display_name": String(metadata.get("default_map_display_name", "")),
	}
