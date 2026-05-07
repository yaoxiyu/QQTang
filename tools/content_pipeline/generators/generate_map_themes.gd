extends ContentCsvGeneratorBase
class_name GenerateMapThemes

const INPUT_CSV_PATH := "res://content_source/csv/map_themes/map_themes.csv"
const OUTPUT_DIR := "res://content/map_themes/data/theme/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("map_themes.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var valid_ids: Array[String] = []

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := MapThemeDef.new()
		def.theme_id = get_cell(row, header_index, "mode_id")
		if def.theme_id.is_empty():
			def.theme_id = get_cell(row, header_index, "theme_id")
		def.display_name = get_cell(row, header_index, "mode_name")
		if def.display_name.is_empty():
			def.display_name = get_cell(row, header_index, "display_name")
		def.bgm_key = get_cell(row, header_index, "bgm_key")
		def.environment_scene = load_resource_or_null(get_cell(row, header_index, "environment_scene_path")) as PackedScene
		def.solid_presentation_id = get_cell(row, header_index, "solid_presentation_id")
		def.breakable_presentation_id = get_cell(row, header_index, "breakable_presentation_id")
		def.tile_palette = {
			"ground": _parse_hex_color(get_cell(row, header_index, "ground_color"), Color(0.88, 0.88, 0.82, 1.0)),
			"solid": _parse_hex_color(get_cell(row, header_index, "solid_color"), Color(0.20, 0.22, 0.28, 1.0)),
			"breakable": _parse_hex_color(get_cell(row, header_index, "breakable_color"), Color(0.70, 0.50, 0.28, 1.0)),
			"spawn": _parse_hex_color(get_cell(row, header_index, "spawn_color"), Color(0.24, 0.42, 0.26, 1.0)),
			"grid_line": _parse_hex_color(get_cell(row, header_index, "grid_line_color"), Color(0.10, 0.12, 0.18, 0.35)),
			"occluder": _parse_hex_color(get_cell(row, header_index, "occluder_color"), Color(0.31, 0.48, 0.32, 1.0)),
		}

		var output_path := OUTPUT_DIR + def.theme_id + ".tres"
		save_resource(def, output_path)
		valid_ids.append(def.theme_id)
	_prune_stale_resources(valid_ids)


func _parse_hex_color(value: String, fallback: Color) -> Color:
	var text := value.strip_edges()
	if text.is_empty():
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	return Color(text)


func _prune_stale_resources(valid_ids: Array[String]) -> void:
	var valid_set: Dictionary = {}
	for id in valid_ids:
		valid_set[id] = true

	for file_name in DirAccess.get_files_at(OUTPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var theme_id := file_name.trim_suffix(".tres")
		if valid_set.has(theme_id):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_DIR + file_name))
