extends ContentCsvGeneratorBase
class_name GenerateCharacters

const INPUT_CSV_PATH := "res://content_source/csv/characters/characters.csv"
const OUTPUT_DIR := "res://content/characters/data/character/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("characters.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := CharacterDef.new()
		def.character_id = get_cell(row, header_index, "character_id")
		def.display_name = get_cell(row, header_index, "display_name")
		def.abbreviation = get_cell(row, header_index, "abbreviation")
		def.illustration_path = get_cell(row, header_index, "illustration_path")
		def.name_image_path = get_cell(row, header_index, "name_image_path")
		def.stats_id = get_cell(row, header_index, "stats_id")
		def.presentation_id = get_cell(row, header_index, "presentation_id")
		def.default_bubble_style_id = get_cell(row, header_index, "default_bubble_style_id")
		def.selection_order = int(get_cell(row, header_index, "selection_order").to_int())
		def.type = _parse_character_type(get_cell(row, header_index, "type"))
		def.selection_icon_path = get_cell(row, header_index, "selection_icon_path")
		def.selection_icon_selected_path = get_cell(row, header_index, "selection_icon_selected_path")
		def.content_hash = "char_def_%s_csv_v2" % def.character_id

		var output_path := OUTPUT_DIR + def.character_id + ".tres"
		save_resource(def, output_path)


func _parse_character_type(value: String) -> int:
	if value.strip_edges().is_empty():
		return 0
	return value.to_int()
