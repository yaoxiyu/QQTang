extends "res://tests/gut/base/qqt_contract_test.gd"

const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")


func test_match_format_catalog_contract() -> void:
	var expected_ids: Array[String] = ["1v1", "2v2", "4v4"]
	var actual_ids := MatchFormatCatalogScript.get_match_format_ids()
	assert_eq(actual_ids, expected_ids, "MatchFormatCatalog ids should match formal content order")
	assert_eq(MatchFormatCatalogScript.get_default_match_format_id(), "1v1", "default match format should be 1v1")

	var metadata_1v1 := MatchFormatCatalogScript.get_metadata("1v1")
	assert_eq(int(metadata_1v1.get("required_party_size", 0)), 1, "1v1 required_party_size should be 1")
	assert_eq(int(metadata_1v1.get("expected_total_player_count", 0)), 2, "1v1 expected_total_player_count should be 2")
	assert_eq(int(metadata_1v1.get("sort_order", 0)), 10, "1v1 sort_order should be 10")

	var metadata_2v2 := MatchFormatCatalogScript.get_metadata("2v2")
	assert_eq(int(metadata_2v2.get("required_party_size", 0)), 2, "2v2 required_party_size should be 2")
	assert_eq(int(metadata_2v2.get("expected_total_player_count", 0)), 4, "2v2 expected_total_player_count should be 4")
	assert_eq(int(metadata_2v2.get("sort_order", 0)), 20, "2v2 sort_order should be 20")

	var metadata_4v4 := MatchFormatCatalogScript.get_metadata("4v4")
	assert_eq(int(metadata_4v4.get("required_party_size", 0)), 4, "4v4 required_party_size should be 4")
	assert_eq(int(metadata_4v4.get("expected_total_player_count", 0)), 8, "4v4 expected_total_player_count should be 8")
	assert_eq(int(metadata_4v4.get("sort_order", 0)), 30, "4v4 sort_order should be 30")
