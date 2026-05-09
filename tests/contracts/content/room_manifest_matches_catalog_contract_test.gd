extends "res://tests/gut/base/qqt_contract_test.gd"

const GenerateRoomManifestScript = preload("res://tools/content_pipeline/generators/generate_room_manifest.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")

const MANIFEST_PATH := "res://build/generated/room_manifest/room_manifest.json"


func test_room_manifest_matches_catalog_contract() -> void:
	GenerateRoomManifestScript.new().generate()

	var manifest := _load_manifest()
	if manifest.is_empty():
		assert_true(false, "room manifest should be generated and readable")
		return

	var maps = manifest.get("maps", [])
	assert_true(maps is Array, "manifest maps should be array")
	if not maps is Array:
		return
	var manifest_maps_by_id := _index_maps_by_id(maps as Array)
	var catalog_maps: Array = MapCatalogScript.get_map_entries()
	assert_eq(manifest_maps_by_id.size(), catalog_maps.size(), "manifest map count should match MapCatalog entries")

	for map_entry_variant in catalog_maps:
		if not map_entry_variant is Dictionary:
			continue
		var map_entry := map_entry_variant as Dictionary
		var map_id := String(map_entry.get("id", ""))
		assert_true(manifest_maps_by_id.has(map_id), "manifest must include map %s" % map_id)
		if not manifest_maps_by_id.has(map_id):
			continue
		var manifest_map := manifest_maps_by_id[map_id] as Dictionary
		assert_eq(String(manifest_map.get("mode_id", "")), String(map_entry.get("bound_mode_id", "")), "mode binding should match map %s" % map_id)
		assert_eq(String(manifest_map.get("rule_set_id", "")), String(map_entry.get("bound_rule_set_id", "")), "ruleset binding should match map %s" % map_id)
		assert_eq(bool(manifest_map.get("custom_room_enabled", false)), bool(map_entry.get("custom_room_enabled", false)), "custom flag should match map %s" % map_id)
		assert_eq(bool(manifest_map.get("casual_enabled", false)), bool(map_entry.get("matchmaking_casual_enabled", false)), "casual flag should match map %s" % map_id)
		assert_eq(bool(manifest_map.get("ranked_enabled", false)), bool(map_entry.get("matchmaking_ranked_enabled", false)), "ranked flag should match map %s" % map_id)
		assert_eq(int(manifest_map.get("required_team_count", 0)), int(map_entry.get("required_team_count", 0)), "required_team_count should match map %s" % map_id)
		assert_eq(int(manifest_map.get("max_player_count", 0)), _expected_custom_room_max_player_count(map_entry), "max_player_count should match custom room capacity for map %s" % map_id)

	var match_formats = manifest.get("match_formats", [])
	assert_true(match_formats is Array, "manifest match_formats should be array")
	if not match_formats is Array:
		return
	var manifest_match_formats_by_id := _index_match_formats_by_id(match_formats as Array)
	var catalog_match_formats := MatchFormatCatalogScript.get_entries()
	assert_eq(manifest_match_formats_by_id.size(), catalog_match_formats.size(), "manifest match format count should match MatchFormatCatalog entries")

	for format_entry in catalog_match_formats:
		var match_format_id := String(format_entry.get("match_format_id", ""))
		assert_true(manifest_match_formats_by_id.has(match_format_id), "manifest must include match format %s" % match_format_id)
		if not manifest_match_formats_by_id.has(match_format_id):
			continue
		var manifest_match_format := manifest_match_formats_by_id[match_format_id] as Dictionary
		assert_eq(
			int(manifest_match_format.get("required_party_size", 0)),
			int(format_entry.get("required_party_size", 0)),
			"required_party_size should match format %s" % match_format_id
		)
		assert_eq(
			int(manifest_match_format.get("expected_total_player_count", 0)),
			int(format_entry.get("expected_total_player_count", 0)),
			"expected_total_player_count should match format %s" % match_format_id
		)
		assert_eq(
			String(manifest_match_format.get("map_pool_resolution_policy", "")),
			String(format_entry.get("map_pool_resolution_policy", "")),
			"map_pool_resolution_policy should match format %s" % match_format_id
		)
		assert_eq(
			_to_sorted_string_array(manifest_match_format.get("legal_mode_ids", [])),
			_expected_legal_mode_ids(match_format_id),
			"legal_mode_ids should match selection/catalog projection for format %s" % match_format_id
		)

	var assets = manifest.get("assets", {})
	assert_true(assets is Dictionary, "manifest assets should be dictionary")
	if not assets is Dictionary:
		return
	var manifest_assets := assets as Dictionary

	assert_eq(String(manifest_assets.get("default_character_id", "")), CharacterCatalogScript.get_default_character_id(), "default_character_id should match CharacterCatalog")
	assert_eq(String(manifest_assets.get("default_bubble_style_id", "")), BubbleCatalogScript.get_default_bubble_id(), "default_bubble_style_id should match BubbleCatalog")

	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_character_ids", [])), _to_sorted_string_array(CharacterCatalogScript.get_character_ids()), "legal_character_ids should match CharacterCatalog")
	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_bubble_style_ids", [])), _to_sorted_string_array(BubbleCatalogScript.get_bubble_ids()), "legal_bubble_style_ids should match BubbleCatalog")


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary


func _index_maps_by_id(maps: Array) -> Dictionary:
	var result: Dictionary = {}
	for map_variant in maps:
		if not map_variant is Dictionary:
			continue
		var map_item := map_variant as Dictionary
		var map_id := String(map_item.get("map_id", ""))
		if map_id.is_empty():
			continue
		result[map_id] = map_item
	return result


func _index_match_formats_by_id(match_formats: Array) -> Dictionary:
	var result: Dictionary = {}
	for format_variant in match_formats:
		if not format_variant is Dictionary:
			continue
		var format_item := format_variant as Dictionary
		var match_format_id := String(format_item.get("match_format_id", ""))
		if match_format_id.is_empty():
			continue
		result[match_format_id] = format_item
	return result


func _expected_legal_mode_ids(match_format_id: String) -> Array[String]:
	var mode_ids: Array[String] = []
	for entry in MapSelectionCatalogScript.get_matchmaking_mode_entries(match_format_id, "casual"):
		var mode_id := String(entry.get("mode_id", ""))
		if mode_id.is_empty() or mode_ids.has(mode_id):
			continue
		mode_ids.append(mode_id)
	for entry in MapSelectionCatalogScript.get_matchmaking_mode_entries(match_format_id, "ranked"):
		var mode_id := String(entry.get("mode_id", ""))
		if mode_id.is_empty() or mode_ids.has(mode_id):
			continue
		mode_ids.append(mode_id)
	mode_ids.sort()
	return mode_ids


func _expected_custom_room_max_player_count(map_entry: Dictionary) -> int:
	var max_player_count := int(map_entry.get("max_player_count", 0))
	var variants = map_entry.get("match_format_variants", [])
	if variants is Array:
		for variant in variants:
			if not variant is Dictionary:
				continue
			max_player_count = maxi(max_player_count, int((variant as Dictionary).get("max_player_count", 0)))
	return max_player_count



func _to_sorted_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(String(item))
	elif value is Array:
		for item in value:
			result.append(String(item))
	result.sort()
	return result
