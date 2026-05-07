extends ContentCsvGeneratorBase
class_name GenerateModes

const INPUT_CSV_PATH := "res://content_source/csv/modes/modes.csv"
const OUTPUT_DIR := "res://content/modes/data/mode/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("modes.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var valid_ids: Array[String] = []

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := ModeDef.new()
		def.mode_id = get_cell(row, header_index, "mode_id")
		def.mode_name = get_cell(row, header_index, "mode_name")
		if def.mode_name.is_empty():
			def.mode_name = get_cell(row, header_index, "display_name")
		def.display_name = def.mode_name
		def.rule_set_id = get_cell(row, header_index, "rule_set_id")
		def.min_player_count = int(get_cell(row, header_index, "min_player_count").to_int())
		def.max_player_count = int(get_cell(row, header_index, "max_player_count").to_int())
		def.allow_character_select = get_cell(row, header_index, "allow_character_select").to_lower() == "true"
		def.allow_bubble_select = get_cell(row, header_index, "allow_bubble_select").to_lower() == "true"
		def.allow_map_select = get_cell(row, header_index, "allow_map_select").to_lower() == "true"
		def.hud_layout_id = get_cell(row, header_index, "hud_layout_id")
		def.default_map_id = get_cell(row, header_index, "default_map_id")
		def.content_hash = "mode_%s_csv_v1" % def.mode_id

		var output_path := OUTPUT_DIR + def.mode_id + ".tres"
		save_resource(def, output_path)
		valid_ids.append(def.mode_id)
	_prune_stale_resources(valid_ids)


func _prune_stale_resources(valid_ids: Array[String]) -> void:
	var valid_set: Dictionary = {}
	for id in valid_ids:
		valid_set[id] = true

	for file_name in DirAccess.get_files_at(OUTPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var mode_id := file_name.trim_suffix(".tres")
		if valid_set.has(mode_id):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_DIR + file_name))
