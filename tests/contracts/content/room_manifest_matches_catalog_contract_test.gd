extends "res://tests/gut/base/qqt_contract_test.gd"

const GenerateRoomManifestScript = preload("res://tools/content_pipeline/generators/generate_room_manifest.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")

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
		assert_eq(int(manifest_map.get("max_player_count", 0)), int(map_entry.get("max_player_count", 0)), "max_player_count should match map %s" % map_id)

	var assets = manifest.get("assets", {})
	assert_true(assets is Dictionary, "manifest assets should be dictionary")
	if not assets is Dictionary:
		return
	var manifest_assets := assets as Dictionary

	assert_eq(String(manifest_assets.get("default_character_id", "")), CharacterCatalogScript.get_default_character_id(), "default_character_id should match CharacterCatalog")
	assert_eq(String(manifest_assets.get("default_bubble_style_id", "")), BubbleCatalogScript.get_default_bubble_id(), "default_bubble_style_id should match BubbleCatalog")

	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_character_ids", [])), _to_sorted_string_array(CharacterCatalogScript.get_character_ids()), "legal_character_ids should match CharacterCatalog")
	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_bubble_style_ids", [])), _to_sorted_string_array(BubbleCatalogScript.get_bubble_ids()), "legal_bubble_style_ids should match BubbleCatalog")
	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_character_skin_ids", [])), _to_sorted_string_array(_character_skin_ids()), "legal_character_skin_ids should match CharacterSkinCatalog")
	assert_eq(_to_sorted_string_array(manifest_assets.get("legal_bubble_skin_ids", [])), _to_sorted_string_array(_bubble_skin_ids()), "legal_bubble_skin_ids should match BubbleSkinCatalog")


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


func _character_skin_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in CharacterSkinCatalogScript.get_all():
		if def == null:
			continue
		var skin_id := String(def.skin_id).strip_edges()
		if skin_id.is_empty():
			continue
		ids.append(skin_id)
	return ids


func _bubble_skin_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in BubbleSkinCatalogScript.get_all():
		if def == null:
			continue
		var skin_id := String(def.bubble_skin_id).strip_edges()
		if skin_id.is_empty():
			continue
		ids.append(skin_id)
	return ids


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
