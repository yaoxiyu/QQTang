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
		var resource := load("%s/%s.tres" % [MAP_RESOURCE_DIR, String(resource_map_id)]) as MapResource
		assert_not_null(resource, "generated map resource must load: %s" % String(resource_map_id))
		if resource == null:
			continue
		_assert_floor_entries_valid(resource)
		_assert_surface_entries_are_valid(resource)


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


func _assert_floor_entries_valid(resource: MapResource) -> void:
	if resource.floor_tile_entries.is_empty():
		return
	for entry in resource.floor_tile_entries:
		var elem_key := String(entry.get("elem_key", "")).strip_edges()
		assert_false(elem_key.is_empty(), "floor elem_key must not be empty: %s" % resource.map_id)
		var texture_path := String(entry.get("texture_path", "")).strip_edges()
		assert_true(_texture_file_exists(texture_path), "floor texture must exist: %s" % texture_path)
		var rect := entry.get("rect", Rect2i()) as Rect2i
		assert_gt(rect.size.x, 0, "floor rect width must be > 0: %s" % resource.map_id)
		assert_gt(rect.size.y, 0, "floor rect height must be > 0: %s" % resource.map_id)


func _assert_surface_entries_are_valid(resource: MapResource) -> void:
	var seen_instances: Dictionary = {}
	for entry in resource.surface_entries:
		var instance_id := String(entry.get("instance_id", "")).strip_edges()
		var elem_key := String(entry.get("elem_key", "")).strip_edges()
		assert_false(instance_id.is_empty(), "surface instance_id must not be empty: %s" % resource.map_id)
		assert_false(elem_key.is_empty(), "surface elem_key must not be empty: %s" % resource.map_id)
		assert_false(seen_instances.has(instance_id), "surface instance_id must be unique: %s" % instance_id)
		seen_instances[instance_id] = true

		var texture_path := String(entry.get("texture_path", "")).strip_edges()
		assert_true(_texture_file_exists(texture_path), "surface texture must exist: %s" % texture_path)
		var anchor_mode := String(entry.get("anchor_mode", ""))
		var interaction_kind := String(entry.get("interaction_kind", ""))
		assert_true(["bottom_right", "bottom_left", "bottom_center"].has(anchor_mode), "surface anchor must be supported: %s" % instance_id)
		assert_true(["solid", "breakable", "trigger_solid"].has(interaction_kind), "surface interaction kind must be supported: %s" % instance_id)
		var cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		var footprint := entry.get("footprint", Vector2i.ONE) as Vector2i
		var collision_footprint := entry.get("collision_footprint", Vector2i.ONE) as Vector2i
		var z_bias := int(entry.get("z_bias", 0))
		var sort_key := entry.get("sort_key", Vector3i.ZERO) as Vector3i
		assert_true(cell.x >= 0 and cell.x < resource.width, "surface x must be in bounds: %s" % instance_id)
		assert_true(cell.y >= 0 and cell.y < resource.height, "surface y must be in bounds: %s" % instance_id)
		assert_true(footprint.x > 0 and footprint.y > 0, "surface footprint must be positive: %s" % instance_id)
		if anchor_mode == "bottom_left":
			assert_true(cell.x + footprint.x <= resource.width, "surface footprint x must fit from bottom-left anchor: %s" % instance_id)
		elif anchor_mode == "bottom_center":
			var footprint_left := cell.x - int(floor(float(footprint.x - 1) / 2.0))
			assert_true(footprint_left >= 0 and footprint_left + footprint.x <= resource.width, "surface footprint x must fit from bottom-center anchor: %s" % instance_id)
		else:
			assert_true(cell.x - footprint.x + 1 >= 0, "surface footprint x must fit from bottom-right anchor: %s" % instance_id)
		assert_true(cell.y - footprint.y + 1 >= 0, "surface footprint y must fit from bottom-right anchor: %s" % instance_id)
		assert_true(collision_footprint.x >= 0 and collision_footprint.y >= 0, "surface collision footprint must be non-negative: %s" % instance_id)
		if anchor_mode == "bottom_left":
			assert_true(cell.x + collision_footprint.x <= resource.width, "surface collision x must fit from bottom-left anchor: %s" % instance_id)
		elif anchor_mode == "bottom_center":
			var collision_left := cell.x - int(floor(float(collision_footprint.x - 1) / 2.0))
			assert_true(collision_left >= 0 and collision_left + collision_footprint.x <= resource.width, "surface collision x must fit from bottom-center anchor: %s" % instance_id)
		else:
			assert_true(cell.x - collision_footprint.x + 1 >= 0, "surface collision x must fit from bottom-right anchor: %s" % instance_id)
		assert_true(cell.y - collision_footprint.y + 1 >= 0, "surface collision y must fit from bottom-right anchor: %s" % instance_id)
		assert_eq(sort_key, Vector3i(cell.y, -cell.x, z_bias), "surface sort key must match render formula: %s" % instance_id)


func _texture_file_exists(resource_path: String) -> bool:
	if resource_path.is_empty():
		return false
	if ResourceLoader.exists(resource_path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(resource_path))
