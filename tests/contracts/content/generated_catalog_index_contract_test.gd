extends "res://tests/gut/base/qqt_contract_test.gd"

const GenerateContentCatalogIndicesScript = preload("res://tools/content_pipeline/generators/generate_content_catalog_indices.gd")
const GeneratedCatalogIndexLoaderScript = preload("res://content/catalog_index/generated_catalog_index_loader.gd")
const GeneratedCatalogIndexContractScript = preload("res://content/catalog_index/generated_catalog_index_contract.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")

const REQUIRED_KINDS := ["characters", "bubbles", "maps", "modes", "rulesets", "match_formats"]


func test_generated_catalog_indices_are_written_and_valid() -> void:
	GenerateContentCatalogIndicesScript.new().generate()

	for kind in REQUIRED_KINDS:
		var path := GeneratedCatalogIndexLoaderScript.index_path(kind)
		assert_true(FileAccess.file_exists(path), "generated catalog index should exist: %s" % path)
		var payload := GeneratedCatalogIndexLoaderScript.load_index(kind)
		var errors: Array[String] = GeneratedCatalogIndexContractScript.validate_payload(payload, kind)
		assert_eq(errors, [], "generated catalog index should be valid for %s" % kind)

	assert_true(
		FileAccess.file_exists("res://build/generated/content_catalog/content_catalog_summary.json"),
		"generated catalog summary should exist"
	)
	_assert_character_type_projection()


func test_generated_index_and_fallback_catalog_paths_have_same_ids() -> void:
	GenerateContentCatalogIndicesScript.new().generate()

	GeneratedCatalogIndexLoaderScript.set_enabled(true)
	_reload_catalogs()
	var generated_ids := _catalog_id_sets()

	GeneratedCatalogIndexLoaderScript.set_enabled(false)
	_reload_catalogs()
	var fallback_ids := _catalog_id_sets()
	GeneratedCatalogIndexLoaderScript.set_enabled(true)

	assert_eq(generated_ids, fallback_ids, "generated-index and fallback catalog paths should expose the same IDs")


func _reload_catalogs() -> void:
	CharacterCatalogScript.load_all()
	BubbleCatalogScript.load_all()
	MapCatalogScript.load_all()
	ModeCatalogScript.load_all()
	RuleSetCatalogScript.load_all()
	MatchFormatCatalogScript.load_all()


func _catalog_id_sets() -> Dictionary:
	return {
		"characters": _sorted(CharacterCatalogScript.get_character_ids()),
		"bubbles": _sorted(BubbleCatalogScript.get_bubble_ids()),
		"maps": _sorted(MapCatalogScript.get_map_ids()),
		"modes": _sorted(ModeCatalogScript.get_mode_ids()),
		"rulesets": _sorted(_field_values(RuleSetCatalogScript.get_rule_entries(), "rule_set_id")),
		"match_formats": _sorted(MatchFormatCatalogScript.get_match_format_ids()),
	}


func _assert_character_type_projection() -> void:
	var entries := GeneratedCatalogIndexLoaderScript.load_entries("characters")
	var by_id := {}
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		by_id[String(entry.get("id", ""))] = entry
	assert_true(by_id.has("10101"), "character index should include default-selectable character 10101")
	assert_true(by_id.has("11301"), "character index should include random-selectable character 11301")
	assert_true(by_id.has("11001"), "character index should include vip character 11001")
	assert_true(by_id.has("11701"), "character index should include defaulted type character 11701")
	assert_true(by_id.has("12301"), "character index should include room random placeholder character 12301")
	if by_id.has("10101"):
		assert_eq(int((by_id["10101"] as Dictionary).get("type", -1)), 1, "10101 type should be default selectable")
	if by_id.has("11301"):
		assert_eq(int((by_id["11301"] as Dictionary).get("type", -1)), 2, "11301 type should be random selectable")
	if by_id.has("11001"):
		assert_eq(int((by_id["11001"] as Dictionary).get("type", -1)), 3, "11001 type should be vip")
	if by_id.has("11701"):
		assert_eq(int((by_id["11701"] as Dictionary).get("type", -1)), 0, "missing character type should default to 0")
	if by_id.has("12301"):
		assert_eq(int((by_id["12301"] as Dictionary).get("type", -1)), 5, "12301 type should be room random placeholder")
		assert_eq(int((by_id["12301"] as Dictionary).get("selection_order", -1)), 0, "12301 should sort first in character selector")


func _field_values(entries: Array, field_name: String) -> Array[String]:
	var result: Array[String] = []
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var value := String((entry_variant as Dictionary).get(field_name, ""))
		if value.is_empty():
			continue
		result.append(value)
	return result


func _sorted(values: Array[String]) -> Array[String]:
	var result := values.duplicate()
	result.sort()
	return result
