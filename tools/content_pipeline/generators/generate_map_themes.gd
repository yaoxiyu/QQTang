extends ContentCsvGeneratorBase
class_name GenerateMapThemes

const INPUT_CSV_PATH := "res://content_source/csv/map_themes/map_themes.csv"
const OUTPUT_DIR := "res://content/map_themes/data/theme/"

func generate() -> void:
    var lines := load_csv_lines(INPUT_CSV_PATH)
    if lines.size() <= 1:
        push_error("map_themes.csv has no data rows")
        return

    var header := split_csv_line(lines[0])
    var header_index := build_header_index(header)

    for i in range(1, lines.size()):
        var row := split_csv_line(lines[i])
        var def := MapThemeDef.new()
        def.theme_id = get_cell(row, header_index, "theme_id")
        def.display_name = get_cell(row, header_index, "display_name")
        def.bgm_key = get_cell(row, header_index, "bgm_key")
        def.environment_scene = load_resource_or_null(get_cell(row, header_index, "environment_scene_path")) as PackedScene

        var output_path := OUTPUT_DIR + def.theme_id + ".tres"
        save_resource(def, output_path)
