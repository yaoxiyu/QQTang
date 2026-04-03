extends ContentCsvGeneratorBase
class_name GenerateBubbleGameplays

const INPUT_CSV_PATH := "res://content_source/csv/bubbles/bubble_gameplays.csv"
const OUTPUT_DIR := "res://content/bubbles/data/gameplay/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("bubble_gameplays.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := BubbleGameplayDef.new()
		def.bubble_gameplay_id = get_cell(row, header_index, "bubble_gameplay_id")
		def.fuse_ticks = int(get_cell(row, header_index, "fuse_ticks").to_int())
		def.move_speed_level = int(roundf(get_cell(row, header_index, "move_speed").to_float()))
		def.can_be_kicked = get_cell(row, header_index, "can_be_kicked").to_lower() == "true"
		def.content_hash = "bubble_gameplay_%s_csv_v1" % def.bubble_gameplay_id

		var output_path := OUTPUT_DIR + def.bubble_gameplay_id + ".tres"
		save_resource(def, output_path)
