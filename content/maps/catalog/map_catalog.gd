class_name MapCatalog
extends RefCounted

const MapResourceScript = preload("res://content/maps/resources/map_resource.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const LogContentScript = preload("res://app/logging/log_content.gd")
const DATA_DIR := "res://content/maps/resources"

const LEGACY_MAP_REGISTRY := {}

static var _map_registry: Dictionary = {}
static var _ordered_map_ids: Array[String] = []


static func load_all() -> void:
	_map_registry.clear()
	_ordered_map_ids.clear()

	if DirAccess.dir_exists_absolute(DATA_DIR):
		for file_name in DirAccess.get_files_at(DATA_DIR):
			if not file_name.ends_with(".tres"):
				continue
			var resource_path := "%s/%s" % [DATA_DIR, file_name]
			var resource := load(resource_path)
			if resource == null or not resource is MapResourceScript:
				LogContentScript.error("MapCatalog failed to load MapResource: %s" % resource_path, "", 0, "content.map.catalog")
				continue
			var map_resource := resource as MapResource
			if map_resource.map_id.is_empty():
				LogContentScript.error("MapCatalog map_id is empty: %s" % resource_path, "", 0, "content.map.catalog")
				continue
			_validate_map_resource(map_resource, resource_path)
			_map_registry[map_resource.map_id] = {
				"display_name": String(map_resource.display_name if not map_resource.display_name.is_empty() else map_resource.map_id),
				"resource_path": resource_path,
				"is_formal": true,
			}

	if _map_registry.is_empty():
		for map_id in LEGACY_MAP_REGISTRY.keys():
			_map_registry[String(map_id)] = LEGACY_MAP_REGISTRY[map_id].duplicate(true)

	for map_id in _map_registry.keys():
		_ordered_map_ids.append(String(map_id))
	_ordered_map_ids.sort()


static func get_map_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_map_ids.duplicate()


static func get_map_entries() -> Array:
	_ensure_loaded()
	var entries: Array = []
	for map_id in _ordered_map_ids:
		var entry: Dictionary = _map_registry[map_id]
		if not bool(entry.get("is_formal", true)):
			continue
		var display_name := String(entry.get("display_name", map_id))
		if display_name.is_empty():
			continue
		var metadata := get_map_metadata(map_id)
		entries.append({
			"id": map_id,
			"display_name": display_name,
			"version": int(metadata.get("version", 1)),
			"content_hash": String(metadata.get("content_hash", "")),
			"width": int(metadata.get("width", 0)),
			"height": int(metadata.get("height", 0)),
			"item_spawn_profile_id": String(metadata.get("item_spawn_profile_id", "")),
			"bound_mode_id": String(metadata.get("bound_mode_id", "")),
			"bound_rule_set_id": String(metadata.get("bound_rule_set_id", "")),
			"match_format_id": String(metadata.get("match_format_id", "")),
			"match_format_variants": metadata.get("match_format_variants", []).duplicate(true),
			"required_team_count": int(metadata.get("required_team_count", 2)),
			"max_player_count": int(metadata.get("max_player_count", 0)),
			"custom_room_enabled": bool(metadata.get("custom_room_enabled", true)),
			"matchmaking_casual_enabled": bool(metadata.get("matchmaking_casual_enabled", true)),
			"matchmaking_ranked_enabled": bool(metadata.get("matchmaking_ranked_enabled", false)),
			"sort_order": int(metadata.get("sort_order", 0)),
			"resource_path": get_map_path(map_id),
		})
	return entries


static func get_default_map_id() -> String:
	_ensure_loaded()
	if _ordered_map_ids.is_empty():
		return ""
	return _ordered_map_ids[0]


static func has_map(map_id: String) -> bool:
	_ensure_loaded()
	return _map_registry.has(map_id)


static func get_map_def_path(_map_id: String) -> String:
	return ""


static func get_map_path(map_id: String) -> String:
	_ensure_loaded()
	if not has_map(map_id):
		return ""
	return String(_map_registry[map_id].get("resource_path", ""))


static func get_map_metadata(map_id: String) -> Dictionary:
	_ensure_loaded()
	if map_id.is_empty() or not has_map(map_id):
		return {}
	var entry: Dictionary = _map_registry[map_id]
	var resource_path := String(entry.get("resource_path", ""))
	if resource_path.is_empty():
		return {}
	var map_resource := load(resource_path)
	if map_resource == null or not map_resource is MapResource:
		return {}
	var metadata := (map_resource as MapResource).to_metadata()
	metadata["id"] = map_id
	metadata["display_name"] = String(entry.get("display_name", metadata.get("display_name", map_id)))
	metadata["resource_path"] = resource_path
	metadata["def_path"] = ""
	metadata["is_formal"] = bool(entry.get("is_formal", true))
	metadata["debug_only"] = bool(entry.get("debug_only", false))
	return metadata


static func _ensure_loaded() -> void:
	if _map_registry.is_empty():
		load_all()


static func _validate_map_resource(map_resource: MapResource, resource_path: String) -> void:
	if map_resource == null:
		return
	var issues: Array[String] = []
	if map_resource.bound_mode_id.is_empty():
		issues.append("bound_mode_id is empty")
	elif not ModeCatalogScript.has_mode(map_resource.bound_mode_id):
		issues.append("bound_mode_id is unknown: %s" % map_resource.bound_mode_id)
	if map_resource.bound_rule_set_id.is_empty():
		issues.append("bound_rule_set_id is empty")
	elif not RuleSetCatalogScript.has_rule(map_resource.bound_rule_set_id):
		issues.append("bound_rule_set_id is unknown: %s" % map_resource.bound_rule_set_id)
	if map_resource.required_team_count < 2:
		issues.append("required_team_count must be >= 2")
	if map_resource.max_player_count <= 0:
		issues.append("max_player_count must be > 0")
	elif map_resource.spawn_points.size() < map_resource.max_player_count:
		issues.append(
			"spawn_points size (%d) is smaller than max_player_count (%d)" % [
				map_resource.spawn_points.size(),
				map_resource.max_player_count,
			]
		)
	for variant in map_resource.match_format_variants:
		if not variant is Dictionary:
			issues.append("match_format_variants entries must be dictionaries")
			continue
		var variant_dict := variant as Dictionary
		var variant_format := String(variant_dict.get("match_format_id", ""))
		var variant_max_players := int(variant_dict.get("max_player_count", map_resource.max_player_count))
		var variant_required_party_size := int(variant_dict.get("required_party_size", 0))
		if variant_format.is_empty():
			issues.append("match_format_variants entry match_format_id is empty")
		elif not MatchFormatCatalogScript.has_match_format(variant_format):
			issues.append("match_format_variants entry match_format_id is unknown: %s" % variant_format)
		else:
			var format_metadata := MatchFormatCatalogScript.get_metadata(variant_format)
			var expected_team_count := int(format_metadata.get("team_count", 0))
			var expected_party_size := int(format_metadata.get("required_party_size", 0))
			var expected_total_players := int(format_metadata.get("expected_total_player_count", 0))
			var variant_team_count := int(variant_dict.get("required_team_count", 0))
			if variant_team_count != expected_team_count:
				issues.append(
					"match_format_variants entry %s required_team_count mismatch: expected=%d actual=%d"
					% [variant_format, expected_team_count, variant_team_count]
				)
			if variant_required_party_size > 0 and variant_required_party_size != expected_party_size:
				issues.append(
					"match_format_variants entry %s required_party_size mismatch: expected=%d actual=%d"
					% [variant_format, expected_party_size, variant_required_party_size]
				)
			if variant_max_players != expected_total_players:
				issues.append(
					"match_format_variants entry %s max_player_count mismatch: expected=%d actual=%d"
					% [variant_format, expected_total_players, variant_max_players]
				)
		if variant_max_players <= 0:
			issues.append("match_format_variants entry max_player_count must be > 0")
		elif map_resource.spawn_points.size() < variant_max_players:
			issues.append(
				"spawn_points size (%d) is smaller than variant %s max_player_count (%d)" % [
					map_resource.spawn_points.size(),
					variant_format,
					variant_max_players,
				]
			)
	if not map_resource.match_format_id.is_empty() and not MatchFormatCatalogScript.has_match_format(map_resource.match_format_id):
		issues.append("match_format_id is unknown: %s" % map_resource.match_format_id)
	if issues.is_empty():
		return
	LogContentScript.warn(
		"MapCatalog validation warning for %s: %s" % [
			resource_path,
			"; ".join(issues),
		],
		"",
		0,
		"content.map.catalog"
	)
