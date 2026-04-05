extends ContentCsvGeneratorBase
class_name GenerateMaps

const INPUT_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const OUTPUT_DIR := "res://content/maps/resources/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("maps.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var map_resource := MapResource.new()
		map_resource.map_id = get_cell(row, header_index, "map_id")
		map_resource.display_name = get_cell(row, header_index, "display_name")
		map_resource.width = int(get_cell(row, header_index, "width").to_int())
		map_resource.height = int(get_cell(row, header_index, "height").to_int())
		map_resource.solid_cells = _parse_layout_cells(get_cell(row, header_index, "layout_rows"), "#")
		map_resource.breakable_cells = _parse_layout_cells(get_cell(row, header_index, "layout_rows"), "*")
		map_resource.spawn_points = _parse_cells(get_cell(row, header_index, "spawn_points"))
		map_resource.item_spawn_profile_id = get_cell(row, header_index, "item_spawn_profile_id")
		if map_resource.item_spawn_profile_id.is_empty():
			map_resource.item_spawn_profile_id = "default_items"
		map_resource.tile_theme_id = get_cell(row, header_index, "theme_id")
		map_resource.foreground_overlay_entries = _parse_foreground_overlay_entries(
			get_cell(row, header_index, "foreground_overlay_entries")
		)
		map_resource.content_hash = "%s_csv_v1" % map_resource.map_id

		var output_path := OUTPUT_DIR + map_resource.map_id + ".tres"
		save_resource(map_resource, output_path)


func _parse_layout_cells(layout_rows_text: String, marker: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rows := split_semicolon(_strip_quotes(layout_rows_text))
	for y in range(rows.size()):
		var row_text := String(rows[y])
		for x in range(row_text.length()):
			if row_text[x] == marker:
				result.append(Vector2i(x, y))
	return result


func _parse_cells(cells_text: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in split_semicolon(_strip_quotes(cells_text)):
		var parts := String(entry).split(":", false)
		if parts.size() != 2:
			continue
		result.append(Vector2i(int(parts[0].to_int()), int(parts[1].to_int())))
	return result


func _parse_foreground_overlay_entries(entries_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in split_semicolon(_strip_quotes(entries_text)):
		var parts := String(entry).split(":", false)
		if parts.size() != 5:
			continue
		result.append({
			"presentation_id": parts[2],
			"cell": Vector2i(int(parts[0].to_int()), int(parts[1].to_int())),
			"offset_px": Vector2(float(parts[3].to_float()), float(parts[4].to_float())),
		})
	return result


func _strip_quotes(value: String) -> String:
	var text := value.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text
