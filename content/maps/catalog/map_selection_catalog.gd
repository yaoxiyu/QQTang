class_name MapSelectionCatalog
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

const MATCH_FORMAT_IDS: Array[String] = ["1v1", "2v2", "4v4"]


static func get_map_binding(map_id: String) -> Dictionary:
	if map_id.is_empty() or not MapCatalogScript.has_map(map_id):
		return {}
	var map_metadata := MapCatalogScript.get_map_metadata(map_id)
	if map_metadata.is_empty():
		return {}
	return _build_legacy_binding(map_metadata)


static func get_custom_room_mode_entries() -> Array[Dictionary]:
	var bindings := _get_valid_bindings(false)
	var entries_by_mode: Dictionary = {}
	for binding in bindings:
		if not bool(binding.get("custom_room_enabled", false)):
			continue
		var mode_id := String(binding.get("bound_mode_id", ""))
		if mode_id.is_empty():
			continue
		if entries_by_mode.has(mode_id):
			continue
		var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
		entries_by_mode[mode_id] = {
			"id": mode_id,
			"mode_id": mode_id,
			"display_name": String(mode_metadata.get("display_name", mode_id)),
			"enabled": true,
			"sort_order": int(binding.get("sort_order", 0)),
		}
	return _sort_mode_entries(entries_by_mode.values())


static func get_custom_room_maps_by_mode(mode_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for binding in _get_valid_bindings(false):
		if not bool(binding.get("custom_room_enabled", false)):
			continue
		if String(binding.get("bound_mode_id", "")) != mode_id:
			continue
		entries.append(_to_map_entry(binding))
	return _sort_map_entries(entries)


static func get_default_custom_room_map_id(preferred_map_id: String = "") -> String:
	if not preferred_map_id.is_empty():
		var preferred_binding := get_map_binding(preferred_map_id)
		if not preferred_binding.is_empty() and bool(preferred_binding.get("valid", false)) and bool(preferred_binding.get("custom_room_enabled", false)):
			return preferred_map_id
	var entries := get_custom_room_mode_entries()
	for entry in entries:
		var mode_id := String(entry.get("mode_id", ""))
		var maps := get_custom_room_maps_by_mode(mode_id)
		if not maps.is_empty():
			return String(maps[0].get("map_id", ""))
	return ""


static func get_matchmaking_format_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for match_format_id in MATCH_FORMAT_IDS:
		var has_enabled_maps := false
		for queue_type in ["casual", "ranked"]:
			var modes := get_matchmaking_mode_entries(match_format_id, queue_type)
			for mode_entry in modes:
				if bool(mode_entry.get("enabled", false)):
					has_enabled_maps = true
					break
			if has_enabled_maps:
				break
		entries.append({
			"id": match_format_id,
			"match_format_id": match_format_id,
			"display_name": match_format_id,
			"enabled": has_enabled_maps,
		})
	return entries


static func get_matchmaking_mode_entries(match_format_id: String, queue_type: String) -> Array[Dictionary]:
	var entries_by_mode: Dictionary = {}
	for binding in _get_valid_bindings(true):
		if String(binding.get("match_format_id", "")) != match_format_id:
			continue
		if not _is_matchmaking_enabled(binding, queue_type):
			continue
		var mode_id := String(binding.get("bound_mode_id", ""))
		if mode_id.is_empty():
			continue
		if entries_by_mode.has(mode_id):
			continue
		var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
		entries_by_mode[mode_id] = {
			"id": mode_id,
			"mode_id": mode_id,
			"display_name": String(mode_metadata.get("display_name", mode_id)),
			"enabled": true,
			"sort_order": int(binding.get("sort_order", 0)),
		}
	return _sort_mode_entries(entries_by_mode.values())


static func get_matchmaking_maps(match_format_id: String, queue_type: String, mode_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for binding in _get_valid_bindings(true):
		if String(binding.get("match_format_id", "")) != match_format_id:
			continue
		if String(binding.get("bound_mode_id", "")) != mode_id:
			continue
		if not _is_matchmaking_enabled(binding, queue_type):
			continue
		entries.append(_to_map_entry(binding))
	return _sort_map_entries(entries)


static func get_match_room_format_entries(queue_type: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for match_format_id in MATCH_FORMAT_IDS:
		var mode_entries := get_match_room_mode_entries(queue_type, match_format_id)
		entries.append({
			"id": match_format_id,
			"match_format_id": match_format_id,
			"display_name": match_format_id,
			"enabled": not mode_entries.is_empty(),
		})
	return entries


static func get_match_room_mode_entries(queue_type: String, match_format_id: String) -> Array[Dictionary]:
	var entries_by_mode: Dictionary = {}
	for binding in _get_valid_bindings(true):
		if String(binding.get("match_format_id", "")) != match_format_id:
			continue
		if not _is_matchmaking_enabled(binding, queue_type):
			continue
		var mode_id := String(binding.get("bound_mode_id", ""))
		if mode_id.is_empty() or entries_by_mode.has(mode_id):
			continue
		var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
		entries_by_mode[mode_id] = {
			"id": mode_id,
			"mode_id": mode_id,
			"display_name": String(mode_metadata.get("display_name", mode_id)),
			"enabled": true,
			"sort_order": int(binding.get("sort_order", 0)),
		}
	return _sort_mode_entries(entries_by_mode.values())


static func get_match_room_eligible_map_count(queue_type: String, match_format_id: String, selected_mode_ids: Array[String]) -> int:
	var map_ids: Dictionary = {}
	for mode_id in selected_mode_ids:
		for entry in get_match_room_maps(queue_type, match_format_id, String(mode_id)):
			var map_id := String(entry.get("map_id", ""))
			if not map_id.is_empty():
				map_ids[map_id] = true
	return map_ids.size()


static func get_match_room_maps(queue_type: String, match_format_id: String, mode_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for binding in _get_valid_bindings(true):
		if String(binding.get("match_format_id", "")) != match_format_id:
			continue
		if String(binding.get("bound_mode_id", "")) != mode_id:
			continue
		if not _is_matchmaking_enabled(binding, queue_type):
			continue
		entries.append(_to_map_entry(binding))
	return _sort_map_entries(entries)


static func _get_valid_bindings(use_matchmaking_variants: bool) -> Array[Dictionary]:
	var bindings: Array[Dictionary] = []
	for map_id in MapCatalogScript.get_map_ids():
		var map_metadata := MapCatalogScript.get_map_metadata(map_id)
		var map_bindings: Array[Dictionary] = []
		if use_matchmaking_variants:
			map_bindings = _build_bindings(map_metadata)
		else:
			map_bindings.append(_build_legacy_binding(map_metadata))
		for binding in map_bindings:
			if binding.is_empty():
				continue
			if not bool(binding.get("valid", false)):
				continue
			bindings.append(binding)
	return bindings


static func _build_legacy_binding(map_metadata: Dictionary) -> Dictionary:
	return _build_binding(map_metadata, {
		"match_format_id": String(map_metadata.get("match_format_id", "2v2")),
		"required_team_count": int(map_metadata.get("required_team_count", 2)),
		"max_player_count": int(map_metadata.get("max_player_count", 0)),
		"custom_room_enabled": bool(map_metadata.get("custom_room_enabled", true)),
		"matchmaking_casual_enabled": bool(map_metadata.get("matchmaking_casual_enabled", true)),
		"matchmaking_ranked_enabled": bool(map_metadata.get("matchmaking_ranked_enabled", false)),
	})


static func _build_bindings(map_metadata: Dictionary) -> Array[Dictionary]:
	if map_metadata.is_empty():
		return []
	var variants := _normalize_match_format_variants(map_metadata)
	var bindings: Array[Dictionary] = []
	for variant in variants:
		bindings.append(_build_binding(map_metadata, variant))
	return bindings


static func _build_binding(map_metadata: Dictionary, variant: Dictionary) -> Dictionary:
	var map_id := String(map_metadata.get("map_id", map_metadata.get("id", "")))
	var bound_mode_id := String(map_metadata.get("bound_mode_id", ""))
	var bound_rule_set_id := String(map_metadata.get("bound_rule_set_id", ""))
	var match_format_id := String(variant.get("match_format_id", map_metadata.get("match_format_id", "2v2")))
	var required_team_count := int(variant.get("required_team_count", map_metadata.get("required_team_count", 2)))
	var max_player_count := int(variant.get("max_player_count", map_metadata.get("max_player_count", 0)))
	var spawn_points = map_metadata.get("spawn_points", [])
	var issues: Array[String] = []

	if map_id.is_empty():
		issues.append("map_id is empty")
	if bound_mode_id.is_empty():
		issues.append("bound_mode_id is empty")
	elif not ModeCatalogScript.has_mode(bound_mode_id):
		issues.append("bound_mode_id is unknown")
	if bound_rule_set_id.is_empty():
		issues.append("bound_rule_set_id is empty")
	elif not RuleSetCatalogScript.has_rule(bound_rule_set_id):
		issues.append("bound_rule_set_id is unknown")
	if not MATCH_FORMAT_IDS.has(match_format_id):
		issues.append("match_format_id is invalid")
	if required_team_count < 2:
		issues.append("required_team_count must be >= 2")
	if max_player_count <= 0:
		issues.append("max_player_count must be > 0")
	if spawn_points is Array and (spawn_points as Array).size() < max_player_count:
		issues.append("spawn_points are insufficient")

	var mode_metadata := ModeCatalogScript.get_mode_metadata(bound_mode_id)
	var rule_metadata := RuleSetCatalogScript.get_rule_metadata(bound_rule_set_id)
	return {
		"map_id": map_id,
		"display_name": String(map_metadata.get("display_name", map_id)),
		"bound_mode_id": bound_mode_id,
		"bound_rule_set_id": bound_rule_set_id,
		"mode_name": String(mode_metadata.get("display_name", bound_mode_id)),
		"rule_set_name": String(rule_metadata.get("display_name", bound_rule_set_id)),
		"match_format_id": match_format_id,
		"required_team_count": required_team_count,
		"max_player_count": max_player_count,
		"custom_room_enabled": bool(variant.get("custom_room_enabled", map_metadata.get("custom_room_enabled", true))),
		"matchmaking_casual_enabled": bool(variant.get("matchmaking_casual_enabled", map_metadata.get("matchmaking_casual_enabled", true))),
		"matchmaking_ranked_enabled": bool(variant.get("matchmaking_ranked_enabled", map_metadata.get("matchmaking_ranked_enabled", false))),
		"sort_order": int(map_metadata.get("sort_order", 0)),
		"content_hash": String(map_metadata.get("content_hash", "")),
		"resource_path": String(map_metadata.get("resource_path", "")),
		"valid": issues.is_empty(),
		"validation_issues": issues,
	}


static func _normalize_match_format_variants(map_metadata: Dictionary) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	var raw_variants = map_metadata.get("match_format_variants", [])
	if raw_variants is Array:
		for raw_variant in raw_variants:
			if not raw_variant is Dictionary:
				continue
			var variant := (raw_variant as Dictionary).duplicate(true)
			if String(variant.get("match_format_id", "")).is_empty():
				continue
			variants.append(variant)
	if variants.is_empty():
		variants.append({
			"match_format_id": String(map_metadata.get("match_format_id", "2v2")),
			"required_team_count": int(map_metadata.get("required_team_count", 2)),
			"max_player_count": int(map_metadata.get("max_player_count", 0)),
		})
	return variants


static func _is_matchmaking_enabled(binding: Dictionary, queue_type: String) -> bool:
	match queue_type:
		"casual":
			return bool(binding.get("matchmaking_casual_enabled", false))
		"ranked":
			return bool(binding.get("matchmaking_ranked_enabled", false))
		_:
			return false


static func _to_map_entry(binding: Dictionary) -> Dictionary:
	return {
		"id": String(binding.get("map_id", "")),
		"map_id": String(binding.get("map_id", "")),
		"display_name": String(binding.get("display_name", "")),
		"mode_id": String(binding.get("bound_mode_id", "")),
		"mode_name": String(binding.get("mode_name", "")),
		"rule_set_id": String(binding.get("bound_rule_set_id", "")),
		"rule_set_name": String(binding.get("rule_set_name", "")),
		"match_format_id": String(binding.get("match_format_id", "")),
		"required_team_count": int(binding.get("required_team_count", 2)),
		"max_player_count": int(binding.get("max_player_count", 0)),
		"sort_order": int(binding.get("sort_order", 0)),
		"enabled": true,
	}


static func _sort_mode_entries(values: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for value in values:
		if value is Dictionary:
			entries.append((value as Dictionary).duplicate(true))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_sort := int(a.get("sort_order", 0))
		var b_sort := int(b.get("sort_order", 0))
		if a_sort == b_sort:
			return String(a.get("display_name", "")) < String(b.get("display_name", ""))
		return a_sort < b_sort
	)
	return entries


static func _sort_map_entries(values: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for value in values:
		entries.append(value.duplicate(true))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_sort := int(a.get("sort_order", 0))
		var b_sort := int(b.get("sort_order", 0))
		if a_sort == b_sort:
			return String(a.get("display_name", "")) < String(b.get("display_name", ""))
		return a_sort < b_sort
	)
	return entries
