extends ContentCsvGeneratorBase
class_name GenerateTilePresentations

const INPUT_CSV_PATH := "res://content_source/csv/tile_presentations/tile_presentations.csv"
const OUTPUT_DIR := "res://content/tiles/data/presentation/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("tile_presentations.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := TilePresentationDef.new()
		def.presentation_id = get_cell(row, header_index, "presentation_id")
		def.display_name = get_cell(row, header_index, "display_name")
		def.render_role = get_cell(row, header_index, "render_role")
		def.tile_scene = load_resource_or_null(get_cell(row, header_index, "tile_scene_path")) as PackedScene
		def.idle_anim = get_cell(row, header_index, "idle_anim")
		def.height_px = float(get_cell(row, header_index, "height_px").to_float())
		def.fade_when_actor_inside = get_cell(row, header_index, "fade_when_actor_inside").to_lower() == "true"
		def.fade_alpha = float(get_cell(row, header_index, "fade_alpha").to_float())
		def.content_hash = get_cell(row, header_index, "content_hash")

		var output_path := OUTPUT_DIR + def.presentation_id + ".tres"
		save_resource(def, output_path)
