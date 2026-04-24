extends "res://tests/gut/base/qqt_contract_test.gd"

const GenerateRoomManifestScript = preload("res://tools/content_pipeline/generators/generate_room_manifest.gd")
const GenerateContentCatalogIndicesScript = preload("res://tools/content_pipeline/generators/generate_content_catalog_indices.gd")
const GeneratedCatalogIndexLoaderScript = preload("res://content/catalog_index/generated_catalog_index_loader.gd")

const MANIFEST_PATH := "res://build/generated/room_manifest/room_manifest.json"


func test_generated_catalog_index_matches_room_manifest() -> void:
	GenerateRoomManifestScript.new().generate()
	GenerateContentCatalogIndicesScript.new().generate()

	var manifest := _load_json(MANIFEST_PATH)
	assert_false(manifest.is_empty(), "room manifest should be readable")
	if manifest.is_empty():
		return

	var assets: Dictionary = manifest.get("assets", {}) if manifest.get("assets", {}) is Dictionary else {}
	_assert_all_in_index(assets.get("legal_character_ids", []), "characters", "manifest legal characters should exist in character index")
	_assert_all_in_index(assets.get("legal_bubble_style_ids", []), "bubbles", "manifest legal bubbles should exist in bubble index")
	_assert_all_in_index(_field_values(manifest.get("maps", []), "map_id"), "maps", "manifest maps should exist in map index")
	_assert_all_in_index(_field_values(manifest.get("modes", []), "mode_id"), "modes", "manifest modes should exist in mode index")
	_assert_all_in_index(_field_values(manifest.get("rules", []), "rule_set_id"), "rulesets", "manifest rules should exist in ruleset index")
	_assert_all_in_index(_field_values(manifest.get("match_formats", []), "match_format_id"), "match_formats", "manifest match formats should exist in match format index")


func _assert_all_in_index(values, kind: String, message: String) -> void:
	var index_ids := _index_ids(kind)
	for value in _to_string_array(values):
		assert_true(index_ids.has(value), "%s: %s" % [message, value])


func _index_ids(kind: String) -> Dictionary:
	var result: Dictionary = {}
	var entries := GeneratedCatalogIndexLoaderScript.load_entries(kind)
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var id := String((entry_variant as Dictionary).get("id", ""))
		if id.is_empty():
			continue
		result[id] = true
	return result


func _field_values(entries, field_name: String) -> Array[String]:
	var result: Array[String] = []
	if not entries is Array:
		return result
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var value := String((entry_variant as Dictionary).get(field_name, ""))
		if value.is_empty():
			continue
		result.append(value)
	return result


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(String(item))
	elif value is Array:
		for item in value:
			result.append(String(item))
	return result
