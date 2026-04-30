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
		def.bubble_type = _parse_int_with_default(get_cell(row, header_index, "type"), 1)
		def.power = _parse_int_with_default(get_cell(row, header_index, "power"), 1)
		def.footprint_cells = _footprint_cells_for_power(def.power)
		def.player_obtainable = _parse_bool_with_default(get_cell(row, header_index, "player_obtainable"), true)
		if not _validate_bubble_shape(def):
			continue
		def.bubble_scene_path = get_cell(row, header_index, "base_scene_path")
		def.icon_path = get_cell(row, header_index, "hud_icon_path")
		def.content_hash = "bubble_style_%s_csv_v2" % def.bubble_style_id

		var output_path := OUTPUT_DIR + def.bubble_style_id + ".tres"
		save_resource(def, output_path)


func _parse_int_with_default(raw_value: String, fallback: int) -> int:
	var value := raw_value.strip_edges()
	if value.is_empty() or not value.is_valid_int():
		return fallback
	return int(value.to_int())


func _parse_bool_with_default(raw_value: String, fallback: bool) -> bool:
	var value := raw_value.strip_edges().to_lower()
	if value.is_empty():
		return fallback
	return value == "true" or value == "1" or value == "yes"


func _footprint_cells_for_power(power: int) -> int:
	return 4 if power >= 2 else 1


func _validate_bubble_shape(def: BubbleStyleDef) -> bool:
	if def.bubble_style_id.is_empty():
		push_error("bubble_styles.csv bubble_style_id is empty")
		return false
	if def.bubble_type < 1 or def.bubble_type > 2:
		push_error("BubbleStyle %s invalid type: %d" % [def.bubble_style_id, def.bubble_type])
		return false
	if def.power < 1 or def.power > 2:
		push_error("BubbleStyle %s invalid power: %d" % [def.bubble_style_id, def.power])
		return false
	return true
