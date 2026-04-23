extends ContentCsvGeneratorBase
class_name GenerateRoomManifest

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")

const OUTPUT_DIR := "res://build/generated/room_manifest"
const OUTPUT_PATH := OUTPUT_DIR + "/room_manifest.json"


func generate() -> void:
	var map_entries: Array = MapCatalogScript.get_map_entries()
	var mode_entries: Array = ModeCatalogScript.get_mode_entries()
	var rule_entries: Array = RuleSetCatalogScript.get_rule_entries()
	var match_format_entries: Array[Dictionary] = MatchFormatCatalogScript.get_entries()

	var format_to_modes: Dictionary = {}
	var mode_to_formats: Dictionary = {}
	var maps: Array[Dictionary] = []

	for entry_variant in map_entries:
		if not entry_variant is Dictionary:
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var mode_id := String(entry.get("bound_mode_id", ""))
		var format_ids := _resolve_map_match_format_ids(entry)

		for format_id in format_ids:
			_add_mode_for_format(format_to_modes, format_id, mode_id)
			_add_format_for_mode(mode_to_formats, mode_id, format_id)

		maps.append({
			"map_id": String(entry.get("id", "")),
			"display_name": String(entry.get("display_name", "")),
			"mode_id": mode_id,
			"rule_set_id": String(entry.get("bound_rule_set_id", "")),
			"match_format_ids": format_ids,
			"required_team_count": int(entry.get("required_team_count", 2)),
			"max_player_count": int(entry.get("max_player_count", 0)),
			"custom_room_enabled": bool(entry.get("custom_room_enabled", true)),
			"casual_enabled": bool(entry.get("matchmaking_casual_enabled", true)),
			"ranked_enabled": bool(entry.get("matchmaking_ranked_enabled", false)),
		})

	var modes: Array[Dictionary] = []
	for entry_variant in mode_entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var mode_id := String(entry.get("mode_id", ""))
		var format_ids: Array[String] = _sorted_string_array(mode_to_formats.get(mode_id, []))
		modes.append({
			"mode_id": mode_id,
			"display_name": String(entry.get("display_name", mode_id)),
			"match_format_ids": format_ids,
			"selectable_in_match_room": not format_ids.is_empty(),
		})

	var rules: Array[Dictionary] = []
	for entry_variant in rule_entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		rules.append({
			"rule_set_id": String(entry.get("rule_set_id", "")),
			"display_name": String(entry.get("display_name", "")),
		})

	var match_formats: Array[Dictionary] = []
	for format_entry in match_format_entries:
		if format_entry.is_empty():
			continue
		var format_id := String(format_entry.get("match_format_id", ""))
		if format_id.is_empty():
			continue
		match_formats.append({
			"match_format_id": format_id,
			"required_party_size": int(format_entry.get("required_party_size", 0)),
			"expected_total_player_count": int(format_entry.get("expected_total_player_count", 0)),
			"legal_mode_ids": _sorted_string_array(format_to_modes.get(format_id, [])),
			"map_pool_resolution_policy": String(format_entry.get("map_pool_resolution_policy", "union_by_selected_modes")),
		})

	var assets := {
		"default_character_id": CharacterCatalogScript.get_default_character_id(),
		"default_bubble_style_id": BubbleCatalogScript.get_default_bubble_id(),
		"legal_character_ids": _sorted_string_array(CharacterCatalogScript.get_character_ids()),
		"legal_character_skin_ids": _sorted_string_array(_character_skin_ids()),
		"legal_bubble_style_ids": _sorted_string_array(BubbleCatalogScript.get_bubble_ids()),
		"legal_bubble_skin_ids": _sorted_string_array(_bubble_skin_ids()),
	}

	var payload := {
		"schema_version": 1,
		"generated_at_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"maps": maps,
		"modes": modes,
		"rules": rules,
		"match_formats": match_formats,
		"assets": assets,
	}

	_ensure_output_dir()
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("failed to write room manifest: %s" % OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _resolve_map_match_format_ids(map_entry: Dictionary) -> Array[String]:
	var format_ids: Array[String] = []
	var primary_format := String(map_entry.get("match_format_id", "")).strip_edges()
	if not primary_format.is_empty():
		format_ids.append(primary_format)

	var variants = map_entry.get("match_format_variants", [])
	if variants is Array:
		for variant in variants:
			if not variant is Dictionary:
				continue
			var format_id := String((variant as Dictionary).get("match_format_id", "")).strip_edges()
			if format_id.is_empty() or format_ids.has(format_id):
				continue
			format_ids.append(format_id)

	format_ids.sort()
	return format_ids


func _add_mode_for_format(format_to_modes: Dictionary, format_id: String, mode_id: String) -> void:
	if format_id.is_empty() or mode_id.is_empty():
		return
	var current = format_to_modes.get(format_id, [])
	var values: Array[String] = _to_string_array(current)
	if values.has(mode_id):
		return
	values.append(mode_id)
	values.sort()
	format_to_modes[format_id] = values


func _add_format_for_mode(mode_to_formats: Dictionary, mode_id: String, format_id: String) -> void:
	if mode_id.is_empty() or format_id.is_empty():
		return
	var current = mode_to_formats.get(mode_id, [])
	var values: Array[String] = _to_string_array(current)
	if values.has(format_id):
		return
	values.append(format_id)
	values.sort()
	mode_to_formats[mode_id] = values


func _character_skin_ids() -> Array[String]:
	var result: Array[String] = []
	for skin_def in CharacterSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		var skin_id := String(skin_def.skin_id).strip_edges()
		if skin_id.is_empty():
			continue
		result.append(skin_id)
	return result


func _bubble_skin_ids() -> Array[String]:
	var result: Array[String] = []
	for skin_def in BubbleSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		var bubble_skin_id := String(skin_def.bubble_skin_id).strip_edges()
		if bubble_skin_id.is_empty():
			continue
		result.append(bubble_skin_id)
	return result


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(String(item))
	elif value is Array:
		for item in value:
			result.append(String(item))
	return result


func _sorted_string_array(value) -> Array[String]:
	var result := _to_string_array(value)
	result.sort()
	return result


func _ensure_output_dir() -> void:
	var global_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
