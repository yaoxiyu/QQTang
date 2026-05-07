extends ContentCsvGeneratorBase
class_name GenerateMaps

const ContentHashUtilScript = preload("res://tools/content_pipeline/common/content_hash_util.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")

const MAPS_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const MAP_VARIANTS_CSV_PATH := "res://content_source/csv/maps/map_match_variants.csv"
const MAP_ELEM_VISUAL_META_CSV_PATH := "res://content_source/csv/maps/map_elem_visual_meta.csv"
const MAP_FLOOR_TILES_CSV_PATH := "res://content_source/csv/maps/map_floor_tiles.csv"
const MAP_SURFACE_INSTANCES_CSV_PATH := "res://content_source/csv/maps/map_surface_instances.csv"
const OUTPUT_DIR := "res://content/maps/resources/"
const GENERATED_FLOOR_TILE_DIR := "res://content/maps/generated/floor_tiles/"


func generate() -> void:
	var csv_reader := ContentCsvReaderScript.new()
	var map_rows := read_csv_rows(MAPS_CSV_PATH)
	var variant_rows := read_csv_rows(MAP_VARIANTS_CSV_PATH)
	var visual_meta_rows := read_csv_rows(MAP_ELEM_VISUAL_META_CSV_PATH)
	var floor_rows := read_csv_rows(MAP_FLOOR_TILES_CSV_PATH)
	var surface_rows := read_csv_rows(MAP_SURFACE_INSTANCES_CSV_PATH)
	if map_rows.is_empty():
		record_error("generate_maps.gd: maps.csv has no data rows")
		return
	if variant_rows.is_empty():
		record_error("generate_maps.gd: map_match_variants.csv has no data rows")
		return
	if visual_meta_rows.is_empty():
		record_error("generate_maps.gd: map_elem_visual_meta.csv has no data rows")
		return
	if floor_rows.is_empty():
		record_error("generate_maps.gd: map_floor_tiles.csv has no data rows")
		return

	ModeCatalogScript.load_all()
	RuleSetCatalogScript.load_all()
	MatchFormatCatalogScript.load_all()

	var variants_by_map_id := _group_variant_rows(variant_rows, csv_reader)
	var visual_meta_by_elem_key := _build_visual_meta_by_elem_key(visual_meta_rows, csv_reader)
	var floor_rows_by_map_id := _group_rows_by_map_id(floor_rows, csv_reader, "map_floor_tiles.csv")
	var surface_rows_by_map_id := _group_rows_by_map_id(surface_rows, csv_reader, "map_surface_instances.csv")
	var valid_map_ids: Array[String] = []
	for map_row in map_rows:
		var map_resource := _build_map_resource(
			map_row,
			variants_by_map_id,
			visual_meta_by_elem_key,
			floor_rows_by_map_id,
			surface_rows_by_map_id,
			csv_reader
		)
		if map_resource == null:
			continue
		valid_map_ids.append(map_resource.map_id)
		save_resource(map_resource, OUTPUT_DIR + map_resource.map_id + ".tres")
	_prune_stale_resources(valid_map_ids)


func _build_map_resource(
	map_row: Dictionary,
	variants_by_map_id: Dictionary,
	visual_meta_by_elem_key: Dictionary,
	floor_rows_by_map_id: Dictionary,
	surface_rows_by_map_id: Dictionary,
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
	if not floor_rows_by_map_id.has(map_id):
		record_error("generate_maps.gd: map %s has no rows in map_floor_tiles.csv" % map_id)
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
	var layout_rows := csv_reader.parse_semicolon_list(csv_reader.optional_string(map_row, "layout_rows", ""))
	var theme_id := csv_reader.require_string(map_row, "theme_id")
	var floor_tile_entries := _build_floor_tile_entries(
		map_id,
		floor_rows_by_map_id[map_id] as Array,
		visual_meta_by_elem_key,
		width,
		height,
		csv_reader
	)
	if floor_tile_entries.is_empty():
		record_error("generate_maps.gd: map %s has no valid floor tile entries" % map_id)
		return null
	var surface_entries := _build_surface_entries(
		map_id,
		surface_rows_by_map_id.get(map_id, []) as Array,
		visual_meta_by_elem_key,
		width,
		height,
		csv_reader
	)
	var decoration_cells: Dictionary = {}
	for entry in surface_entries:
		if String(entry.get("logic_type", "")) == "decoration":
			var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
			var fp: Vector2i = entry.get("footprint", Vector2i.ONE)
			for fy in range(fp.y):
				for fx in range(fp.x):
					decoration_cells[Vector2i(cell.x + fx, cell.y + fy)] = true
	if not _floor_entries_cover_map(map_id, floor_tile_entries, width, height, decoration_cells):
		return null
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
	if surface_entries.is_empty():
		map_resource.solid_cells = _parse_layout_cells(layout_rows, "#")
		map_resource.breakable_cells = _parse_layout_cells(layout_rows, "*")
	else:
		map_resource.solid_cells = _collect_surface_cells(surface_entries, ["solid", "trigger_solid"])
		map_resource.breakable_cells = _collect_surface_cells(surface_entries, ["breakable"])
	map_resource.spawn_points = spawn_points
	map_resource.item_spawn_profile_id = csv_reader.optional_string(map_row, "item_spawn_profile_id", "default_items")
	map_resource.tile_theme_id = theme_id
	map_resource.floor_tile_entries = floor_tile_entries
	map_resource.surface_entries = surface_entries
	map_resource.bound_mode_id = bound_mode_id
	map_resource.bound_rule_set_id = bound_rule_set_id
	map_resource.match_format_id = String(default_variant.get("match_format_id", ""))
	map_resource.required_team_count = int(default_variant.get("required_team_count", 0))
	map_resource.max_player_count = spawn_points.size()
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
		"floor_tile_entries": map_resource.floor_tile_entries,
		"surface_entries": map_resource.surface_entries,
		"bound_mode_id": map_resource.bound_mode_id,
		"bound_rule_set_id": map_resource.bound_rule_set_id,
		"custom_room_enabled": map_resource.custom_room_enabled,
		"sort_order": map_resource.sort_order,
		"match_format_variants": match_format_variants,
	})
	return map_resource


func _group_rows_by_map_id(rows: Array[Dictionary], csv_reader: ContentCsvReader, csv_name: String) -> Dictionary:
	var grouped: Dictionary = {}
	for row in rows:
		var map_id := csv_reader.require_string(row, "map_id")
		if map_id.is_empty():
			record_error("generate_maps.gd: %s row missing map_id" % csv_name)
			continue
		if not grouped.has(map_id):
			grouped[map_id] = []
		var bucket: Array = grouped[map_id]
		bucket.append(row)
	return grouped


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


func _build_visual_meta_by_elem_key(rows: Array[Dictionary], csv_reader: ContentCsvReader) -> Dictionary:
	var result: Dictionary = {}
	for row in rows:
		var elem_key := csv_reader.require_string(row, "elem_key")
		if elem_key.is_empty():
			record_error("generate_maps.gd: map_elem_visual_meta.csv row missing elem_key")
			continue
		if result.has(elem_key):
			record_error("generate_maps.gd: duplicate elem_key in map_elem_visual_meta.csv: %s" % elem_key)
			continue
		result[elem_key] = row
	return result


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
		result.append({
			"match_format_id": match_format_id,
			"required_team_count": int(metadata.get("team_count", 0)),
			"required_party_size": int(metadata.get("required_party_size", 0)),
			"max_player_count": int(metadata.get("expected_total_player_count", 0)),
			"matchmaking_casual_enabled": csv_reader.parse_bool(variant_row.get("casual_enabled", "false"), false),
			"matchmaking_ranked_enabled": csv_reader.parse_bool(variant_row.get("ranked_enabled", "false"), false),
			"sort_order": int(metadata.get("sort_order", 0)),
		})
		seen_match_formats[match_format_id] = true

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_sort := int(a.get("sort_order", 0))
		var right_sort := int(b.get("sort_order", 0))
		if left_sort == right_sort:
			return String(a.get("match_format_id", "")) < String(b.get("match_format_id", ""))
		return left_sort < right_sort
	)
	return result


func _build_floor_tile_entries(
	map_id: String,
	rows: Array,
	visual_meta_by_elem_key: Dictionary,
	width: int,
	height: int,
	csv_reader: ContentCsvReader
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row_value in rows:
		var row: Dictionary = row_value
		var elem_key := csv_reader.require_string(row, "elem_key")
		var visual_meta := _require_visual_meta(map_id, elem_key, visual_meta_by_elem_key)
		if visual_meta.is_empty():
			continue
		var texture_path := String(visual_meta.get("resource_path", ""))
		if String(visual_meta.get("visual_layer", "")) != "floor":
			record_error("generate_maps.gd: map %s floor elem_key must reference a 40x40 floor asset: %s" % [map_id, elem_key])
			continue
		var expand := csv_reader.parse_int(row.get("expand", "0"), 0) == 1
		if expand:
			texture_path = _build_expanded_floor_texture(map_id, elem_key, texture_path)
		var x := csv_reader.parse_int(row.get("x", ""), -1)
		var y := csv_reader.parse_int(row.get("y", ""), -1)
		var w := csv_reader.parse_int(row.get("w", ""), 0)
		var h := csv_reader.parse_int(row.get("h", ""), 0)
		if texture_path.is_empty() or x < 0 or y < 0 or w <= 0 or h <= 0:
			record_error("generate_maps.gd: map %s has invalid floor tile entry" % map_id)
			continue
		if x + w > width or y + h > height:
			record_error("generate_maps.gd: map %s floor tile entry out of bounds" % map_id)
			continue
		if not _texture_file_exists(texture_path):
			record_error("generate_maps.gd: map %s floor texture missing: %s" % [map_id, texture_path])
			continue
		result.append({
			"elem_key": elem_key,
			"texture_path": texture_path,
			"rect": Rect2i(x, y, w, h),
		})
	return result


func _build_surface_entries(
	map_id: String,
	rows: Array,
	visual_meta_by_elem_key: Dictionary,
	width: int,
	height: int,
	csv_reader: ContentCsvReader
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_instances: Dictionary = {}
	for row_value in rows:
		var row: Dictionary = row_value
		var instance_id := csv_reader.require_string(row, "instance_id")
		var elem_key := csv_reader.require_string(row, "elem_key")
		var visual_meta := _require_visual_meta(map_id, elem_key, visual_meta_by_elem_key)
		if visual_meta.is_empty():
			continue
		var texture_path := String(visual_meta.get("resource_path", ""))
		var x := csv_reader.parse_int(row.get("x", ""), -1)
		var y := csv_reader.parse_int(row.get("y", ""), -1)
		var footprint_w := csv_reader.parse_int(visual_meta.get("footprint_w", ""), 1)
		var footprint_h := csv_reader.parse_int(visual_meta.get("footprint_h", ""), 1)
		var z_bias := csv_reader.parse_int(row.get("z_bias", visual_meta.get("z_bias", "")), 0)
		var interaction_kind := csv_reader.optional_string(visual_meta, "interaction_kind", "solid")
		if instance_id.is_empty() or elem_key.is_empty() or texture_path.is_empty():
			record_error("generate_maps.gd: map %s has surface entry with empty id, elem_key, or texture" % map_id)
			continue
		if seen_instances.has(instance_id):
			record_error("generate_maps.gd: map %s duplicate surface instance_id=%s" % [map_id, instance_id])
			continue
		if x < 0 or y < 0 or x >= width or y >= height:
			record_error("generate_maps.gd: map %s surface entry out of bounds: %s" % [map_id, instance_id])
			continue
		if footprint_w <= 0 or footprint_h <= 0 or x + footprint_w > width or y + footprint_h > height:
			record_error("generate_maps.gd: map %s surface footprint out of bounds: %s" % [map_id, instance_id])
			continue
		if not _texture_file_exists(texture_path):
			record_error("generate_maps.gd: map %s surface texture missing: %s" % [map_id, texture_path])
			continue
		seen_instances[instance_id] = true
		result.append({
			"instance_id": instance_id,
			"elem_key": elem_key,
			"texture_path": texture_path,
			"cell": Vector2i(x, y),
			"footprint": Vector2i(footprint_w, footprint_h),
			"anchor_mode": csv_reader.optional_string(visual_meta, "anchor_mode", "bottom_right"),
			"offset_px": Vector2.ZERO,
			"z_bias": z_bias,
			"render_role": csv_reader.optional_string(row, "render_role", "surface"),
			"interaction_kind": interaction_kind,
			"die_texture_path": csv_reader.optional_string(visual_meta, "die_resource_path", ""),
			"trigger_texture_path": csv_reader.optional_string(visual_meta, "trigger_resource_path", ""),
			"sort_key": Vector3i(y + footprint_h - 1, -x, z_bias),
			"logic_type": csv_reader.optional_string(visual_meta, "logic_type", "decoration"),
		})
	return result


func _collect_surface_cells(surface_entries: Array[Dictionary], interaction_kinds: Array[String]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for entry in surface_entries:
		var interaction_kind := String(entry.get("interaction_kind", "solid"))
		if not interaction_kinds.has(interaction_kind):
			continue
		var cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		if seen.has(cell):
			continue
		seen[cell] = true
		result.append(cell)
	result.sort()
	return result


func _build_expanded_floor_texture(map_id: String, elem_key: String, source_path: String) -> String:
	if source_path.is_empty() or not _texture_file_exists(source_path):
		return source_path
	var source_image := Image.new()
	if source_image.load(ProjectSettings.globalize_path(source_path)) != OK:
		return source_path
	if source_image.get_width() != 40 or source_image.get_height() != 40:
		return source_path
	var expanded := _dilate_floor_alpha(source_image)
	var output_path := "%s%s.png" % [GENERATED_FLOOR_TILE_DIR, elem_key.replace("/", "_")]
	var output_dir := ProjectSettings.globalize_path(GENERATED_FLOOR_TILE_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if expanded.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		record_error("generate_maps.gd: map %s failed to save expanded floor texture: %s" % [map_id, output_path])
		return source_path
	return output_path


func _texture_file_exists(resource_path: String) -> bool:
	if resource_path.is_empty():
		return false
	if ResourceLoader.exists(resource_path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(resource_path))


func _dilate_floor_alpha(source_image: Image) -> Image:
	var current := source_image.duplicate()
	for _i in range(40):
		var next := current.duplicate()
		var changed := false
		for y in range(current.get_height()):
			for x in range(current.get_width()):
				if current.get_pixel(x, y).a > 0.01:
					continue
				var replacement := _find_neighbor_color(current, x, y)
				if replacement.a <= 0.01:
					continue
				next.set_pixel(x, y, replacement)
				changed = true
		current = next
		if not changed:
			break
	return current


func _find_neighbor_color(image: Image, x: int, y: int) -> Color:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x := x + offset_x
			var sample_y := y + offset_y
			if sample_x < 0 or sample_y < 0 or sample_x >= image.get_width() or sample_y >= image.get_height():
				continue
			var color := image.get_pixel(sample_x, sample_y)
			if color.a > 0.01:
				return color
	return Color.TRANSPARENT


func _require_visual_meta(map_id: String, elem_key: String, visual_meta_by_elem_key: Dictionary) -> Dictionary:
	if elem_key.is_empty():
		record_error("generate_maps.gd: map %s references empty elem_key" % map_id)
		return {}
	if not visual_meta_by_elem_key.has(elem_key):
		record_error("generate_maps.gd: map %s references unknown elem_key=%s" % [map_id, elem_key])
		return {}
	return visual_meta_by_elem_key[elem_key] as Dictionary


func _floor_entries_cover_map(map_id: String, entries: Array[Dictionary], width: int, height: int, decoration_cells: Dictionary = {}) -> bool:
	var covered: Dictionary = {}
	for entry in entries:
		var rect := entry.get("rect", Rect2i()) as Rect2i
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				covered[Vector2i(x, y)] = true
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not covered.has(pos) and not decoration_cells.has(pos):
				record_error("generate_maps.gd: map %s floor missing cell %d:%d" % [map_id, x, y])
				return false
	return true


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
