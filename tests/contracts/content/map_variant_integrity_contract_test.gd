extends "res://tests/gut/base/qqt_contract_test.gd"

const ContentCsvReaderScript = preload("res://tools/content_pipeline/common/content_csv_reader.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")

const MAPS_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const MAP_VARIANTS_CSV_PATH := "res://content_source/csv/maps/map_match_variants.csv"


func test_map_variant_integrity_contract() -> void:
	var csv_reader := ContentCsvReaderScript.new()
	var map_rows := csv_reader.read_rows(MAPS_CSV_PATH)
	var variant_rows := csv_reader.read_rows(MAP_VARIANTS_CSV_PATH)
	var maps_by_id := _index_maps_by_id(map_rows)

	for variant_row in variant_rows:
		var map_id := String(variant_row.get("map_id", "")).strip_edges()
		var match_format_id := String(variant_row.get("match_format_id", "")).strip_edges()
		assert_true(maps_by_id.has(map_id), "variant map_id must exist in maps.csv: %s" % map_id)
		assert_true(MatchFormatCatalogScript.has_match_format(match_format_id), "variant match_format_id must exist in MatchFormatCatalog: %s" % match_format_id)
		if not maps_by_id.has(map_id) or not MatchFormatCatalogScript.has_match_format(match_format_id):
			continue
		var map_row := maps_by_id[map_id] as Dictionary
		var spawn_points := csv_reader.parse_vector2i_list(map_row.get("spawn_points", ""))
		var expected_total_player_count := MatchFormatCatalogScript.get_expected_total_player_count(match_format_id)
		assert_true(
			spawn_points.size() >= expected_total_player_count,
			"spawn_points must satisfy expected_total_player_count for %s:%s" % [map_id, match_format_id]
		)


func _index_maps_by_id(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for row in rows:
		var map_id := String(row.get("map_id", "")).strip_edges()
		if map_id.is_empty():
			continue
		result[map_id] = row
	return result
