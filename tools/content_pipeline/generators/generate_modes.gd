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

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := ModeDef.new()
		def.mode_id = get_cell(row, header_index, "mode_id")
		def.display_name = get_cell(row, header_index, "display_name")
		def.rule_set_id = get_cell(row, header_index, "rule_set_id")
		def.min_player_count = int(get_cell(row, header_index, "min_player_count").to_int())
		def.max_player_count = int(get_cell(row, header_index, "max_player_count").to_int())
		def.allow_character_select = get_cell(row, header_index, "allow_character_select").to_lower() == "true"
		def.allow_bubble_select = get_cell(row, header_index, "allow_bubble_select").to_lower() == "true"
		def.allow_map_select = get_cell(row, header_index, "allow_map_select").to_lower() == "true"
		def.hud_layout_id = get_cell(row, header_index, "hud_layout_id")
		def.content_hash = "mode_%s_csv_v1" % def.mode_id

		if def.mode_id == "mode_classic":
			def.default_map_id = "map_classic_square"
		elif def.mode_id == "mode_quick_match":
			def.default_map_id = "map_classic_square"

		var output_path := OUTPUT_DIR + def.mode_id + ".tres"
		save_resource(def, output_path)
