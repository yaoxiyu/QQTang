extends RefCounted
class_name ExportMapsSourceSnapshot

const MapResourceScript = preload("res://content/maps/resources/map_resource.gd")

const INPUT_DIR := "res://content/maps/resources"
const OUTPUT_DIR := "res://build/generated/content_migration/maps_source_snapshot"
const MAPS_OUTPUT_PATH := OUTPUT_DIR + "/maps.csv"
const VARIANTS_OUTPUT_PATH := OUTPUT_DIR + "/map_match_variants.csv"

const MAPS_HEADER := [
	"map_id",
	"display_name",
	"preview_image_path",
	"width",
	"height",
	"layout_rows",
	"spawn_points",
	"theme_id",
	"item_spawn_profile_id",
	"foreground_overlay_entries",
	"bound_mode_id",
	"bound_rule_set_id",
	"custom_room_enabled",
	"sort_order",
]

const VARIANTS_HEADER := [
	"map_id",
	"match_format_id",
	"casual_enabled",
	"ranked_enabled",
]


func generate() -> void:
	var map_rows: Array[PackedStringArray] = []
	var variant_rows: Array[PackedStringArray] = []

	if not DirAccess.dir_exists_absolute(INPUT_DIR):
		push_error("ExportMapsSourceSnapshot input dir missing: %s" % INPUT_DIR)
		return

	var resource_paths: Array[String] = []
	for file_name in DirAccess.get_files_at(INPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		resource_paths.append("%s/%s" % [INPUT_DIR, file_name])
	resource_paths.sort()

	for resource_path in resource_paths:
		var resource := load(resource_path)
		if resource == null or not resource is MapResourceScript:
			push_error("ExportMapsSourceSnapshot failed to load map resource: %s" % resource_path)
			continue
		var map_resource := resource as MapResource
		if map_resource.map_id.is_empty():
			push_error("ExportMapsSourceSnapshot encountered map resource with empty map_id: %s" % resource_path)
			continue

		map_rows.append(_build_map_row(map_resource))
		variant_rows.append_array(_build_variant_rows(map_resource))

	_ensure_output_dir()
	_write_csv(MAPS_OUTPUT_PATH, MAPS_HEADER, map_rows)
	_write_csv(VARIANTS_OUTPUT_PATH, VARIANTS_HEADER, variant_rows)


func _build_map_row(map_resource: MapResource) -> PackedStringArray:
	return PackedStringArray([
		map_resource.map_id,
		map_resource.display_name,
		_resolve_preview_image_path(map_resource.map_id),
		str(map_resource.width),
		str(map_resource.height),
		_encode_layout_rows(map_resource),
		_encode_spawn_points(map_resource.spawn_points),
		map_resource.tile_theme_id,
		map_resource.item_spawn_profile_id,
		_encode_foreground_overlay_entries(map_resource.foreground_overlay_entries),
		map_resource.bound_mode_id,
		map_resource.bound_rule_set_id,
		_bool_text(map_resource.custom_room_enabled),
		str(map_resource.sort_order),
	])


func _build_variant_rows(map_resource: MapResource) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var variant_entries := map_resource.match_format_variants
	if variant_entries.is_empty() and not map_resource.match_format_id.is_empty():
		variant_entries = [{
			"match_format_id": map_resource.match_format_id,
		}]

	for variant in variant_entries:
		if not variant is Dictionary:
			push_error("ExportMapsSourceSnapshot invalid match_format_variants entry for map_id=%s" % map_resource.map_id)
			continue
		var match_format_id := String((variant as Dictionary).get("match_format_id", "")).strip_edges()
		if match_format_id.is_empty():
			push_error("ExportMapsSourceSnapshot empty variant match_format_id for map_id=%s" % map_resource.map_id)
			continue
		rows.append(PackedStringArray([
			map_resource.map_id,
			match_format_id,
			_bool_text(_resolve_variant_casual_enabled(map_resource, variant as Dictionary)),
			_bool_text(_resolve_variant_ranked_enabled(map_resource, variant as Dictionary)),
		]))
	return rows


func _resolve_variant_casual_enabled(map_resource: MapResource, variant: Dictionary) -> bool:
	if variant.has("matchmaking_casual_enabled"):
		return bool(variant.get("matchmaking_casual_enabled", false))
	return map_resource.matchmaking_casual_enabled


func _resolve_variant_ranked_enabled(map_resource: MapResource, variant: Dictionary) -> bool:
	if variant.has("matchmaking_ranked_enabled"):
		return bool(variant.get("matchmaking_ranked_enabled", false))
	return map_resource.matchmaking_ranked_enabled


func _encode_layout_rows(map_resource: MapResource) -> String:
	var solid_lookup: Dictionary = {}
	for cell in map_resource.solid_cells:
		solid_lookup[_vector2i_key(cell)] = true

	var breakable_lookup: Dictionary = {}
	for cell in map_resource.breakable_cells:
		breakable_lookup[_vector2i_key(cell)] = true

	var rows: Array[String] = []
	for y in range(map_resource.height):
		var chars: Array[String] = []
		for x in range(map_resource.width):
			var key := _vector2i_key(Vector2i(x, y))
			if solid_lookup.has(key):
				chars.append("#")
			elif breakable_lookup.has(key):
				chars.append("*")
			else:
				chars.append(".")
		rows.append("".join(chars))
	return ";".join(rows)


func _encode_spawn_points(spawn_points: Array[Vector2i]) -> String:
	var parts: Array[String] = []
	for spawn_point in spawn_points:
		parts.append("%d:%d" % [spawn_point.x, spawn_point.y])
	return ";".join(parts)


func _encode_foreground_overlay_entries(entries: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in entries:
		var cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		var presentation_id := String(entry.get("presentation_id", "")).strip_edges()
		var offset := entry.get("offset_px", Vector2.ZERO) as Vector2
		parts.append("%d:%d:%s:%s:%s" % [
			cell.x,
			cell.y,
			presentation_id,
			_format_number(offset.x),
			_format_number(offset.y),
		])
	return ";".join(parts)


func _resolve_preview_image_path(map_id: String) -> String:
	var preview_name := map_id
	if preview_name.begins_with("map_"):
		preview_name = preview_name.substr(4)
	return "res://ui/maps/%s.png" % preview_name


func _bool_text(value: bool) -> String:
	return "true" if value else "false"


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value)


func _vector2i_key(value: Vector2i) -> String:
	return "%d:%d" % [value.x, value.y]


func _write_csv(output_path: String, header: Array[String], rows: Array[PackedStringArray]) -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("ExportMapsSourceSnapshot failed to open output: %s" % output_path)
		return
	file.store_csv_line(PackedStringArray(header))
	for row in rows:
		file.store_csv_line(row)
	file.close()


func _ensure_output_dir() -> void:
	var global_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
