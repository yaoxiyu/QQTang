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
		def.initial_bubble_count = _read_int(row, header_index, "initial_bubble_count", "base_bomb_count", 1)
		def.max_bubble_count = maxi(def.initial_bubble_count, _read_int(row, header_index, "max_bubble_count", "", 5))
		def.initial_bubble_power = _read_int(row, header_index, "initial_bubble_power", "base_power", 1)
		def.max_bubble_power = maxi(def.initial_bubble_power, _read_int(row, header_index, "max_bubble_power", "", 5))
		def.initial_move_speed = maxi(1, _read_int(row, header_index, "initial_move_speed", "base_speed", 1))
		def.max_move_speed = maxi(def.initial_move_speed, _read_int(row, header_index, "max_move_speed", "", 9))
		def.content_hash = "char_stats_%s_csv_v1" % def.stats_id

		var output_path := OUTPUT_DIR + def.stats_id + ".tres"
		save_resource(def, output_path)


func _read_int(row: PackedStringArray, header_index: Dictionary, primary_key: String, fallback_key: String, default_value: int) -> int:
	if header_index.has(primary_key):
		var primary := get_cell(row, header_index, primary_key)
		if not primary.is_empty():
			return int(roundf(primary.to_float()))
	if not fallback_key.is_empty() and header_index.has(fallback_key):
		var fallback := get_cell(row, header_index, fallback_key)
		if not fallback.is_empty():
			return int(roundf(fallback.to_float()))
	return default_value
