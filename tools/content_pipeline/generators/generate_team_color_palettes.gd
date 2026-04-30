extends ContentCsvGeneratorBase
class_name GenerateTeamColorPalettes

const TeamColorPaletteDefScript = preload("res://content/team_colors/defs/team_color_palette_def.gd")

const INPUT_CSV_PATH := "res://content_source/csv/team_colors/team_palettes.csv"
const OUTPUT_DIR := "res://content/team_colors/data/palettes/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("team_palettes.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var palettes: Dictionary = {}
	var palette_hashes: Dictionary = {}

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var palette_id := get_cell(row, header_index, "palette_id")
		var team_id := get_cell(row, header_index, "team_id").to_int()
		if palette_id.is_empty():
			push_error("team_palettes.csv palette_id is empty")
			continue
		if team_id < 1:
			push_error("team_palettes.csv invalid team_id for %s: %d" % [palette_id, team_id])
			continue
		if not palettes.has(palette_id):
			palettes[palette_id] = {}
			palette_hashes[palette_id] = []
		var teams := palettes[palette_id] as Dictionary
		if teams.has(team_id):
			push_error("team_palettes.csv duplicate team_id %d in %s" % [team_id, palette_id])
			continue
		teams[team_id] = {
			"team_color_id": get_cell(row, header_index, "team_color_id"),
			"label": get_cell(row, header_index, "label"),
			"primary": _parse_hex_color(get_cell(row, header_index, "primary_hex")),
			"secondary": _parse_hex_color(get_cell(row, header_index, "secondary_hex")),
			"shadow": _parse_hex_color(get_cell(row, header_index, "shadow_hex")),
			"highlight": _parse_hex_color(get_cell(row, header_index, "highlight_hex")),
			"ui_color": _parse_hex_color(get_cell(row, header_index, "ui_color_hex")),
		}
		var hashes := palette_hashes[palette_id] as Array
		hashes.append(get_cell(row, header_index, "content_hash"))

	for palette_id in palettes.keys():
		var teams := palettes[palette_id] as Dictionary
		for expected_team_id in range(1, 9):
			if not teams.has(expected_team_id):
				push_error("team palette %s missing team_id %d" % [palette_id, expected_team_id])
				continue
		var def := TeamColorPaletteDefScript.new()
		def.palette_id = String(palette_id)
		def.display_name = String(palette_id)
		def.team_colors = teams
		def.content_hash = "|".join(palette_hashes[palette_id])
		save_resource(def, OUTPUT_DIR + String(palette_id) + ".tres")


func _parse_hex_color(value: String) -> Color:
	var text := value.strip_edges()
	if text.is_empty():
		return Color.WHITE
	if not text.begins_with("#"):
		text = "#" + text
	return Color(text)

