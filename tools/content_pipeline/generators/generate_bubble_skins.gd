extends ContentCsvGeneratorBase
class_name GenerateBubbleSkins

const INPUT_CSV_PATH := "res://content_source/csv/bubble_skins/bubble_skins.csv"
const OUTPUT_DIR := "res://content/bubble_skins/data/skins/"

func generate() -> void:
    var lines := load_csv_lines(INPUT_CSV_PATH)
    if lines.size() <= 1:
        push_error("bubble_skins.csv has no data rows")
        return

    var header := split_csv_line(lines[0])
    var header_index := build_header_index(header)

    for i in range(1, lines.size()):
        var row := split_csv_line(lines[i])
        var def := BubbleSkinDef.new()
        def.bubble_skin_id = get_cell(row, header_index, "bubble_skin_id")
        def.display_name = get_cell(row, header_index, "display_name")
        def.overlay_scene = load_resource_or_null(get_cell(row, header_index, "overlay_scene_path")) as PackedScene
        def.icon = load_resource_or_null(get_cell(row, header_index, "icon_path")) as Texture2D
        def.tags = split_semicolon(get_cell(row, header_index, "tags"))

        var output_path := OUTPUT_DIR + def.bubble_skin_id + ".tres"
        save_resource(def, output_path)
