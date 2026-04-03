extends ContentCsvGeneratorBase
class_name GenerateCharacterStats

const INPUT_CSV_PATH := "res://content_source/csv/characters/character_stats.csv"
const OUTPUT_DIR := "res://content/characters/data/stats/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("character_stats.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := CharacterStatsDef.new()
		def.stats_id = get_cell(row, header_index, "stats_id")
		def.base_bomb_count = int(get_cell(row, header_index, "base_bomb_count").to_int())
		def.base_firepower = int(get_cell(row, header_index, "base_power").to_int())
		def.base_move_speed = maxi(1, int(roundf(get_cell(row, header_index, "base_speed").to_float())))
		def.content_hash = "char_stats_%s_csv_v1" % def.stats_id

		var output_path := OUTPUT_DIR + def.stats_id + ".tres"
		save_resource(def, output_path)
