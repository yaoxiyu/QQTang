extends ContentCsvGeneratorBase
class_name GenerateBubbleStyles

const INPUT_CSV_PATH := "res://content_source/csv/bubbles/bubble_styles.csv"
const OUTPUT_DIR := "res://content/bubbles/data/style/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("bubble_styles.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := BubbleStyleDef.new()
		def.bubble_style_id = get_cell(row, header_index, "bubble_style_id")
		def.display_name = get_cell(row, header_index, "display_name")
		def.animation_set_id = get_cell(row, header_index, "animation_set_id")
		def.bubble_scene_path = get_cell(row, header_index, "base_scene_path")
		def.icon_path = get_cell(row, header_index, "hud_icon_path")
		def.content_hash = "bubble_style_%s_csv_v1" % def.bubble_style_id

		var output_path := OUTPUT_DIR + def.bubble_style_id + ".tres"
		save_resource(def, output_path)
