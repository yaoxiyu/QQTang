extends ContentCsvGeneratorBase
class_name GenerateCharacterSkins

const INPUT_CSV_PATH := "res://content_source/csv/character_skins/character_skins.csv"
const OUTPUT_DIR := "res://content/character_skins/data/skins/"

func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("character_skins.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := CharacterSkinDef.new()
		def.skin_id = get_cell(row, header_index, "skin_id")
		def.display_name = get_cell(row, header_index, "display_name")
		def.overlay_scene = load_resource_or_null(get_cell(row, header_index, "overlay_scene_path")) as PackedScene
		def.applicable_slots = split_semicolon(get_cell(row, header_index, "applicable_slots"))
		def.ui_icon = load_resource_or_null(get_cell(row, header_index, "ui_icon_path")) as Texture2D
		def.rarity = get_cell(row, header_index, "rarity")
		def.tags = split_semicolon(get_cell(row, header_index, "tags"))

		var output_path := OUTPUT_DIR + def.skin_id + ".tres"
		save_resource(def, output_path)
