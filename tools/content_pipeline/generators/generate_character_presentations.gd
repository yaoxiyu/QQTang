extends ContentCsvGeneratorBase
class_name GenerateCharacterPresentations

const INPUT_CSV_PATH := "res://content_source/csv/characters/character_presentations.csv"
const OUTPUT_DIR := "res://content/characters/data/presentation/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("character_presentations.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := CharacterPresentationDef.new()
		def.presentation_id = get_cell(row, header_index, "presentation_id")
		def.display_name = _build_display_name_from_presentation_id(def.presentation_id)
		def.body_scene = load_resource_or_null(get_cell(row, header_index, "body_scene_path")) as PackedScene
		def.animation_set_id = get_cell(row, header_index, "animation_set_id")
		def.body_view_type = get_cell(row, header_index, "body_view_type")
		if def.body_view_type.is_empty():
			def.body_view_type = "sprite_frames_2d"
		def.animation_library_path = get_cell(row, header_index, "animation_library_path")
		def.idle_anim = get_cell(row, header_index, "idle_anim")
		def.run_anim = get_cell(row, header_index, "run_anim")
		def.dead_anim = get_cell(row, header_index, "dead_anim")
		def.hud_portrait_small = load_resource_or_null(get_cell(row, header_index, "hud_portrait_small_path")) as Texture2D
		def.hud_portrait_large = load_resource_or_null(get_cell(row, header_index, "hud_portrait_large_path")) as Texture2D
		def.skin_anchor_slots = split_semicolon(get_cell(row, header_index, "skin_anchor_slots"))
		def.actor_scene_path = get_cell(row, header_index, "body_scene_path")
		def.portrait_small_path = get_cell(row, header_index, "hud_portrait_small_path")
		def.portrait_large_path = get_cell(row, header_index, "hud_portrait_large_path")
		def.content_hash = "char_pres_%s_csv_v1" % def.presentation_id

		var output_path := OUTPUT_DIR + def.presentation_id + ".tres"
		save_resource(def, output_path)


func _build_display_name_from_presentation_id(presentation_id: String) -> String:
	return presentation_id.trim_prefix("char_pres_").replace("_", " ").capitalize()
