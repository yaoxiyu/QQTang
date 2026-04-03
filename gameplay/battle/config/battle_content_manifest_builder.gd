class_name BattleContentManifestBuilder
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const BattleItemConfigBuilderScript = preload("res://gameplay/battle/config/battle_item_config_builder.gd")
const BattleBubbleContentBuilderScript = preload("res://gameplay/battle/config/battle_bubble_content_builder.gd")
const BattleModeContentBuilderScript = preload("res://gameplay/battle/config/battle_mode_content_builder.gd")

var _item_config_builder = BattleItemConfigBuilderScript.new()
var _bubble_content_builder = BattleBubbleContentBuilderScript.new()
var _mode_content_builder = BattleModeContentBuilderScript.new()


func build_for_start_config(start_config: BattleStartConfig) -> Dictionary:
	if start_config == null:
		return {}
	var map_metadata := MapCatalogScript.get_map_metadata(String(start_config.map_id))
	var rule_metadata := RuleCatalogScript.get_rule_metadata(String(start_config.rule_set_id))
	var item_config := _item_config_builder.build_for_start_config(start_config)
	var mode_metadata := _mode_content_builder.build_for_mode_id(String(start_config.mode_id))
	var characters := _build_character_entries(start_config)
	var bubbles := _bubble_content_builder.build_for_start_config(start_config)
	return _build_manifest(map_metadata, rule_metadata, mode_metadata, item_config, characters, bubbles, start_config.map_id, start_config.rule_set_id, start_config.mode_id)


func build_preview_manifest(map_id: String, rule_set_id: String) -> Dictionary:
	var map_metadata := MapCatalogScript.get_map_metadata(map_id)
	var rule_metadata := RuleCatalogScript.get_rule_metadata(rule_set_id)
	var fallback_item_profile_id := String(map_metadata.get("item_spawn_profile_id", "default_items"))
	var item_config := _item_config_builder.build_for_rule(rule_set_id, fallback_item_profile_id)
	return _build_manifest(map_metadata, rule_metadata, {}, item_config, [], [], map_id, rule_set_id, "")


func _build_manifest(
	map_metadata: Dictionary,
	rule_metadata: Dictionary,
	mode_metadata: Dictionary,
	item_config: Dictionary,
	characters: Array[Dictionary],
	bubbles: Array[Dictionary],
	fallback_map_id: String,
	fallback_rule_id: String,
	fallback_mode_id: String
) -> Dictionary:
	var map_manifest := _build_map_manifest(map_metadata)
	var rule_manifest := _build_rule_manifest(rule_metadata)
	var mode_manifest := _build_mode_manifest(mode_metadata)
	var item_brief := _build_item_brief(item_config)
	var bubble_brief := _build_bubble_brief(bubbles)
	return {
		"map": map_manifest,
		"rule": rule_manifest,
		"mode": mode_manifest,
		"items": item_config.get("enabled_items", []).duplicate(true),
		"item_config": item_config,
		"characters": characters,
		"bubbles": bubbles,
		"ui_summary": {
			"map_display_name": String(map_manifest.get("display_name", fallback_map_id)),
			"map_brief": String(map_manifest.get("brief", "")),
			"rule_display_name": String(rule_manifest.get("display_name", fallback_rule_id)),
			"rule_brief": String(rule_manifest.get("brief", "")),
			"mode_display_name": String(mode_manifest.get("display_name", fallback_mode_id)),
			"bubble_brief": bubble_brief,
			"item_profile_id": String(item_config.get("profile_id", map_manifest.get("item_spawn_profile_id", "default_items"))),
			"item_brief": item_brief,
		},
	}


func _build_character_entries(start_config: BattleStartConfig) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for loadout in start_config.character_loadouts:
		var character_id := String(loadout.get("character_id", ""))
		var metadata := CharacterLoaderScript.load_character_metadata(character_id)
		if metadata.is_empty():
			continue
		var entry := metadata.duplicate(true)
		entry["peer_id"] = int(loadout.get("peer_id", -1))
		entry["character_id"] = character_id
		entry["brief"] = "%s | 炸弹:%d 火力:%d 速度:%d" % [
			String(metadata.get("display_name", character_id)),
			int(metadata.get("base_bomb_count", 0)),
			int(metadata.get("base_firepower", 0)),
			int(metadata.get("base_move_speed", 0)),
		]
		entries.append(entry)
	return entries


func _build_map_manifest(map_metadata: Dictionary) -> Dictionary:
	var width := int(map_metadata.get("width", 0))
	var height := int(map_metadata.get("height", 0))
	var item_spawn_profile_id := String(map_metadata.get("item_spawn_profile_id", "default_items"))
	return {
		"map_id": String(map_metadata.get("map_id", map_metadata.get("id", ""))),
		"display_name": String(map_metadata.get("display_name", "")),
		"brief": _build_map_brief(map_metadata),
		"width": width,
		"height": height,
		"item_spawn_profile_id": item_spawn_profile_id,
		"content_hash": String(map_metadata.get("content_hash", "")),
		"tags": [
			"%dx%d" % [width, height],
			"掉落:%s" % item_spawn_profile_id,
		],
	}


func _build_rule_manifest(rule_metadata: Dictionary) -> Dictionary:
	return {
		"rule_set_id": String(rule_metadata.get("rule_set_id", rule_metadata.get("id", ""))),
		"display_name": String(rule_metadata.get("display_name", "")),
		"brief": _build_rule_brief(rule_metadata),
		"description": String(rule_metadata.get("description", "")),
		"version": int(rule_metadata.get("version", 1)),
		"round_time_sec": int(rule_metadata.get("round_time_sec", 0)),
		"starting_bomb_count": int(rule_metadata.get("starting_bomb_count", 1)),
		"starting_firepower": int(rule_metadata.get("starting_firepower", 1)),
		"starting_speed": int(rule_metadata.get("starting_speed", 1)),
		"item_drop_profile": String(rule_metadata.get("item_drop_profile", "")),
		"ui_tags": rule_metadata.get("ui_tags", []).duplicate(),
		"tags": [
			"%ds" % int(rule_metadata.get("round_time_sec", 0)),
			"炸弹:%d" % int(rule_metadata.get("starting_bomb_count", 1)),
			"火力:%d" % int(rule_metadata.get("starting_firepower", 1)),
			"速度:%d" % int(rule_metadata.get("starting_speed", 1)),
		],
	}


func _build_mode_manifest(mode_metadata: Dictionary) -> Dictionary:
	return {
		"mode_id": String(mode_metadata.get("mode_id", "")),
		"display_name": String(mode_metadata.get("display_name", "")),
		"rule_set_id": String(mode_metadata.get("rule_set_id", "")),
		"default_map_id": String(mode_metadata.get("default_map_id", "")),
		"min_player_count": int(mode_metadata.get("min_player_count", 1)),
		"max_player_count": int(mode_metadata.get("max_player_count", 4)),
		"allow_character_select": bool(mode_metadata.get("allow_character_select", true)),
		"allow_bubble_select": bool(mode_metadata.get("allow_bubble_select", true)),
		"allow_map_select": bool(mode_metadata.get("allow_map_select", true)),
		"hud_layout_id": String(mode_metadata.get("hud_layout_id", "default")),
		"content_hash": String(mode_metadata.get("content_hash", "")),
		"brief": _build_mode_brief(mode_metadata),
	}


func _build_map_brief(map_metadata: Dictionary) -> String:
	var width := int(map_metadata.get("width", 0))
	var height := int(map_metadata.get("height", 0))
	var item_profile_id := String(map_metadata.get("item_spawn_profile_id", "default_items"))
	return "%dx%d | 掉落配置: %s" % [width, height, item_profile_id]


func _build_rule_brief(rule_metadata: Dictionary) -> String:
	var round_time_sec := int(rule_metadata.get("round_time_sec", 0))
	var starting_bomb_count := int(rule_metadata.get("starting_bomb_count", 1))
	var starting_firepower := int(rule_metadata.get("starting_firepower", 1))
	var starting_speed := int(rule_metadata.get("starting_speed", 1))
	return "%ds | 炸弹:%d 火力:%d 速度:%d" % [
		round_time_sec,
		starting_bomb_count,
		starting_firepower,
		starting_speed,
	]


func _build_item_brief(item_config: Dictionary) -> String:
	var enabled_items: Array = item_config.get("enabled_items", [])
	var item_names: PackedStringArray = PackedStringArray()
	for entry in enabled_items:
		item_names.append(String(entry.get("display_name", entry.get("item_id", ""))))
	var profile_id := String(item_config.get("profile_id", "default_items"))
	if item_names.is_empty():
		return "掉落:%s | 无道具" % profile_id
	return "掉落:%s | %s" % [profile_id, " / ".join(item_names)]


func _build_mode_brief(mode_metadata: Dictionary) -> String:
	var rule_set_id := String(mode_metadata.get("rule_set_id", ""))
	var min_player_count := int(mode_metadata.get("min_player_count", 1))
	var max_player_count := int(mode_metadata.get("max_player_count", 4))
	return "规则:%s | 人数:%d-%d" % [
		rule_set_id,
		min_player_count,
		max_player_count,
	]


func _build_bubble_brief(bubbles: Array[Dictionary]) -> String:
	var bubble_names: PackedStringArray = PackedStringArray()
	for entry in bubbles:
		var display_name := String(entry.get("display_name", entry.get("bubble_style_id", "")))
		if display_name.is_empty():
			continue
		bubble_names.append(display_name)
	if bubble_names.is_empty():
		return ""
	return "泡泡:%s" % " / ".join(bubble_names)
