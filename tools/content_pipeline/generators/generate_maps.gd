extends ContentCsvGeneratorBase
class_name GenerateMaps

const ContentHashUtilScript = preload("res://tools/content_pipeline/common/content_hash_util.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")

const MAPS_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const MAP_VARIANTS_CSV_PATH := "res://content_source/csv/maps/map_match_variants.csv"
const OUTPUT_DIR := "res://content/maps/resources/"


func generate() -> void:
	var csv_reader := ContentCsvReaderScript.new()
	var map_rows := read_csv_rows(MAPS_CSV_PATH)
	var variant_rows := read_csv_rows(MAP_VARIANTS_CSV_PATH)
	if map_rows.is_empty():
		record_error("generate_maps.gd: maps.csv has no data rows")
		return
	if variant_rows.is_empty():
		record_error("generate_maps.gd: map_match_variants.csv has no data rows")
		return

	ModeCatalogScript.load_all()
	RuleSetCatalogScript.load_all()
	MatchFormatCatalogScript.load_all()

	var variants_by_map_id := _group_variant_rows(variant_rows, csv_reader)
	var valid_map_ids: Array[String] = []
	for map_row in map_rows:
		var map_resource := _build_map_resource(map_row, variants_by_map_id, csv_reader)
		if map_resource == null:
			continue
		valid_map_ids.append(map_resource.map_id)
		var output_path := OUTPUT_DIR + map_resource.map_id + ".tres"
		save_resource(map_resource, output_path)
	_prune_stale_resources(valid_map_ids)


func _build_map_resource(
	map_row: Dictionary,
	variants_by_map_id: Dictionary,
	csv_reader: ContentCsvReader
) -> MapResource:
	var map_id := csv_reader.require_string(map_row, "map_id")
	if map_id.is_empty():
		record_error("generate_maps.gd: encountered map row with empty map_id")
		return null

	var bound_mode_id := csv_reader.require_string(map_row, "bound_mode_id")
	if bound_mode_id.is_empty():
		record_error("generate_maps.gd: map %s missing bound_mode_id" % map_id)
		return null
	if not ModeCatalogScript.has_mode(bound_mode_id):
		record_error("generate_maps.gd: map %s has unknown bound_mode_id=%s" % [map_id, bound_mode_id])
		return null

	var mode_metadata := ModeCatalogScript.get_mode_metadata(bound_mode_id)
	var bound_rule_set_id := csv_reader.optional_string(map_row, "bound_rule_set_id", "")
	if bound_rule_set_id.is_empty():
		bound_rule_set_id = String(mode_metadata.get("rule_set_id", ""))
	if bound_rule_set_id.is_empty():
		record_error("generate_maps.gd: map %s could not resolve bound_rule_set_id" % map_id)
		return null
	if not RuleSetCatalogScript.has_rule(bound_rule_set_id):
		record_error("generate_maps.gd: map %s has unknown bound_rule_set_id=%s" % [map_id, bound_rule_set_id])
		return null

	if not variants_by_map_id.has(map_id):
		record_error("generate_maps.gd: map %s has no rows in map_match_variants.csv" % map_id)
		return null

	var match_format_variants := _build_match_format_variants(
		map_id,
		variants_by_map_id[map_id] as Array[Dictionary],
		csv_reader
	)
	if match_format_variants.is_empty():
		record_error("generate_maps.gd: map %s has no valid match format variants" % map_id)
		return null

	var spawn_points := csv_reader.parse_vector2i_list(map_row.get("spawn_points", ""))
	var display_name := csv_reader.require_string(map_row, "display_name")
	var width := csv_reader.parse_int(map_row.get("width", ""), 0)
	var height := csv_reader.parse_int(map_row.get("height", ""), 0)
	var layout_rows_text := csv_reader.require_string(map_row, "layout_rows")
	var layout_rows := csv_reader.parse_semicolon_list(layout_rows_text)
	var theme_id := csv_reader.require_string(map_row, "theme_id")
	var default_variant := _select_default_variant(match_format_variants)
	if default_variant.is_empty():
		record_error("generate_maps.gd: map %s failed to resolve default match format variant" % map_id)
		return null

	for variant in match_format_variants:
		var variant_max_players := int(variant.get("max_player_count", 0))
		if spawn_points.size() < variant_max_players:
			record_error(
				"generate_maps.gd: map %s spawn_points size (%d) is smaller than variant %s max_player_count (%d)"
				% [map_id, spawn_points.size(), String(variant.get("match_format_id", "")), variant_max_players]
			)
			return null

	var map_resource := MapResource.new()
	map_resource.map_id = map_id
	map_resource.display_name = display_name
	map_resource.width = width
	map_resource.height = height
	map_resource.solid_cells = _parse_layout_cells(layout_rows, "#")
	map_resource.breakable_cells = _parse_layout_cells(layout_rows, "*")
	map_resource.spawn_points = spawn_points
	map_resource.item_spawn_profile_id = csv_reader.optional_string(map_row, "item_spawn_profile_id", "default_items")
	map_resource.tile_theme_id = theme_id
	map_resource.foreground_overlay_entries = _parse_foreground_overlay_entries(
		String(map_row.get("foreground_overlay_entries", ""))
	)
	map_resource.bound_mode_id = bound_mode_id
	map_resource.bound_rule_set_id = bound_rule_set_id
	map_resource.match_format_id = String(default_variant.get("match_format_id", ""))
	map_resource.required_team_count = int(default_variant.get("required_team_count", 0))
	map_resource.max_player_count = int(default_variant.get("max_player_count", 0))
	map_resource.match_format_variants = match_format_variants
	map_resource.custom_room_enabled = csv_reader.parse_bool(map_row.get("custom_room_enabled", "true"), true)
	map_resource.matchmaking_casual_enabled = _has_enabled_queue(match_format_variants, "matchmaking_casual_enabled")
	map_resource.matchmaking_ranked_enabled = _has_enabled_queue(match_format_variants, "matchmaking_ranked_enabled")
	map_resource.sort_order = csv_reader.parse_int(map_row.get("sort_order", "0"), 0)
	map_resource.content_hash = ContentHashUtilScript.hash_dictionary({
		"map_id": map_resource.map_id,
		"display_name": map_resource.display_name,
		"preview_image_path": csv_reader.optional_string(map_row, "preview_image_path", ""),
		"width": map_resource.width,
		"height": map_resource.height,
		"layout_rows": Array(layout_rows),
		"spawn_points": map_resource.spawn_points,
		"theme_id": map_resource.tile_theme_id,
		"item_spawn_profile_id": map_resource.item_spawn_profile_id,
		"foreground_overlay_entries": map_resource.foreground_overlay_entries,
		"bound_mode_id": map_resource.bound_mode_id,
		"bound_rule_set_id": map_resource.bound_rule_set_id,
		"custom_room_enabled": map_resource.custom_room_enabled,
		"sort_order": map_resource.sort_order,
		"match_format_variants": match_format_variants,
	})
	return map_resource


func _group_variant_rows(variant_rows: Array[Dictionary], csv_reader: ContentCsvReader) -> Dictionary:
	var grouped: Dictionary = {}
	for variant_row in variant_rows:
		var map_id := csv_reader.require_string(variant_row, "map_id")
		var match_format_id := csv_reader.require_string(variant_row, "match_format_id")
		if map_id.is_empty() or match_format_id.is_empty():
			record_error("generate_maps.gd: variant row missing map_id or match_format_id")
			continue
		if not grouped.has(map_id):
			grouped[map_id] = []
		var variant_bucket: Array = grouped[map_id]
		variant_bucket.append(variant_row)
	return grouped


func _build_match_format_variants(
	map_id: String,
	variant_rows: Array,
	csv_reader: ContentCsvReader
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_match_formats: Dictionary = {}
	for variant_row_value in variant_rows:
		var variant_row: Dictionary = variant_row_value
		var match_format_id := csv_reader.require_string(variant_row, "match_format_id")
		if match_format_id.is_empty():
			record_error("generate_maps.gd: map %s has variant row with empty match_format_id" % map_id)
			continue
		if seen_match_formats.has(match_format_id):
			record_error("generate_maps.gd: map %s has duplicate match_format_id=%s" % [map_id, match_format_id])
			continue
		if not MatchFormatCatalogScript.has_match_format(match_format_id):
			record_error("generate_maps.gd: map %s references unknown match_format_id=%s" % [map_id, match_format_id])
			continue

		var metadata := MatchFormatCatalogScript.get_metadata(match_format_id)
		var variant := {
			"match_format_id": match_format_id,
			"required_team_count": int(metadata.get("team_count", 0)),
			"required_party_size": int(metadata.get("required_party_size", 0)),
			"max_player_count": int(metadata.get("expected_total_player_count", 0)),
			"matchmaking_casual_enabled": csv_reader.parse_bool(variant_row.get("casual_enabled", "false"), false),
			"matchmaking_ranked_enabled": csv_reader.parse_bool(variant_row.get("ranked_enabled", "false"), false),
			"sort_order": int(metadata.get("sort_order", 0)),
		}
		result.append(variant)
		seen_match_formats[match_format_id] = true

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_sort := int(a.get("sort_order", 0))
		var right_sort := int(b.get("sort_order", 0))
		if left_sort == right_sort:
			return String(a.get("match_format_id", "")) < String(b.get("match_format_id", ""))
		return left_sort < right_sort
	)
	return result


func _select_default_variant(match_format_variants: Array[Dictionary]) -> Dictionary:
	if match_format_variants.is_empty():
		return {}
	return match_format_variants[0]


func _has_enabled_queue(match_format_variants: Array[Dictionary], key: String) -> bool:
	for variant in match_format_variants:
		if bool(variant.get(key, false)):
			return true
	return false


func _parse_layout_cells(layout_rows: PackedStringArray, marker: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(layout_rows.size()):
		var row_text := String(layout_rows[y])
		for x in range(row_text.length()):
			if row_text[x] == marker:
				result.append(Vector2i(x, y))
	return result


func _parse_foreground_overlay_entries(entries_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries := entries_text.strip_edges()
	if entries.is_empty():
		return result
	for entry in entries.split(";", false):
		var parts := String(entry).split(":", false)
		if parts.size() != 5:
			record_error("generate_maps.gd: invalid foreground_overlay_entries entry=%s" % entry)
			continue
		result.append({
			"presentation_id": String(parts[2]).strip_edges(),
			"cell": Vector2i(int(String(parts[0]).to_int()), int(String(parts[1]).to_int())),
			"offset_px": Vector2(float(String(parts[3]).to_float()), float(String(parts[4]).to_float())),
		})
	return result


func _prune_stale_resources(valid_map_ids: Array[String]) -> void:
	var valid_id_set: Dictionary = {}
	for map_id in valid_map_ids:
		valid_id_set[map_id] = true

	for file_name in DirAccess.get_files_at(OUTPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var map_id := file_name.trim_suffix(".tres")
		if valid_id_set.has(map_id):
			continue
		var stale_path := OUTPUT_DIR + file_name
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
		if err != OK:
			record_error("generate_maps.gd: failed to delete stale map resource %s err=%d" % [stale_path, err])
