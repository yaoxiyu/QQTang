extends "res://tests/gut/base/qqt_contract_test.gd"

const ContentCsvReaderScript = preload("res://tools/content_pipeline/common/content_csv_reader.gd")
const MAPS_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const MAP_RESOURCE_DIR := "res://content/maps/resources"


func test_map_resource_generation_contract() -> void:
	var csv_reader := ContentCsvReaderScript.new()
	var source_rows := csv_reader.read_rows(MAPS_CSV_PATH)
	var source_map_ids := _collect_source_map_ids(source_rows)
	var resource_map_ids := _collect_resource_map_ids()

	for source_map_id in source_map_ids:
		assert_true(resource_map_ids.has(source_map_id), "source map must have generated resource: %s" % source_map_id)

	for resource_map_id in resource_map_ids.keys():
		assert_true(source_map_ids.has(String(resource_map_id)), "generated resource must have source row: %s" % String(resource_map_id))


func _collect_source_map_ids(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for row in rows:
		var map_id := String(row.get("map_id", "")).strip_edges()
		if map_id.is_empty():
			continue
		result[map_id] = true
	return result


func _collect_resource_map_ids() -> Dictionary:
	var result: Dictionary = {}
	for file_name in DirAccess.get_files_at(MAP_RESOURCE_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var map_id := file_name.trim_suffix(".tres")
		if map_id.is_empty():
			continue
		result[map_id] = true
	return result
