extends ContentCsvGeneratorBase
class_name GenerateRulesets

const INPUT_CSV_PATH := "res://content_source/csv/rulesets/rulesets.csv"
const OUTPUT_DIR := "res://content/rulesets/data/rule_set/"

func generate() -> void:
    var lines := load_csv_lines(INPUT_CSV_PATH)
    if lines.size() <= 1:
        push_error("rulesets.csv has no data rows")
        return

    var header := split_csv_line(lines[0])
    var header_index := build_header_index(header)

    for i in range(1, lines.size()):
        var row := split_csv_line(lines[i])
        var def := RuleSetDef.new()
        def.rule_set_id = get_cell(row, header_index, "rule_set_id")
        def.time_limit_sec = int(get_cell(row, header_index, "time_limit_sec"))
        def.round_count = int(get_cell(row, header_index, "round_count"))
        def.respawn_enabled = get_cell(row, header_index, "respawn_enabled") == "true"
        def.friendly_fire = get_cell(row, header_index, "friendly_fire") == "true"
        def.sudden_death_enabled = get_cell(row, header_index, "sudden_death_enabled") == "true"
        def.item_drop_profile_id = get_cell(row, header_index, "item_drop_profile_id")
        def.score_policy = get_cell(row, header_index, "score_policy")

        var output_path := OUTPUT_DIR + def.rule_set_id + ".tres"
        save_resource(def, output_path)
