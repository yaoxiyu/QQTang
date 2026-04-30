class_name RoomTeamPalette
extends RefCounted

const TeamColorPaletteLoaderScript = preload("res://content/team_colors/runtime/team_color_palette_loader.gd")

const DEFAULT_PALETTE_ID := "team_palette_default_8"
const TEAM_IDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const TEAM_LABELS: Array[String] = ["A", "B", "C", "D", "E", "F", "G", "H"]
const TEAM_COLORS: Array[Color] = [
	Color(0.34901962, 0.43529412, 0.78039217, 1.0),
	Color(0.78039217, 0.36078432, 0.4392157, 1.0),
	Color(0.36078432, 0.7490196, 0.45882353, 1.0),
	Color(0.78039217, 0.6627451, 0.36078432, 1.0),
	Color(0.41568628, 0.7529412, 0.78039217, 1.0),
	Color(0.6392157, 0.36078432, 0.78039217, 1.0),
	Color(0.78039217, 0.4745098, 0.36078432, 1.0),
	Color(0.36078432, 0.56078434, 0.45882353, 1.0),
]


static func label_for_team(team_id: int) -> String:
	var index := clampi(team_id - 1, 0, TEAM_LABELS.size() - 1)
	return TEAM_LABELS[index]


static func color_for_team(team_id: int) -> Color:
	var palette := TeamColorPaletteLoaderScript.load_palette(DEFAULT_PALETTE_ID)
	if palette != null and palette.has_method("get_team_color"):
		var team_color: Dictionary = palette.get_team_color(team_id)
		var palette_color: Variant = team_color.get("ui_color", team_color.get("primary", null))
		if palette_color is Color:
			return palette_color
	var index := clampi(team_id - 1, 0, TEAM_COLORS.size() - 1)
	return TEAM_COLORS[index]
