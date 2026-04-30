class_name RoomTeamPalette
extends RefCounted

const TeamColorPaletteLoaderScript = preload("res://content/team_colors/runtime/team_color_palette_loader.gd")

const DEFAULT_PALETTE_ID := "team_palette_default_8"
const TEAM_IDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const TEAM_LABELS: Array[String] = ["A", "B", "C", "D", "E", "F", "G", "H"]
const TEAM_COLORS: Array[Color] = [
	Color("#C94124"),
	Color("#2E42C8"),
	Color("#EFE84A"),
	Color("#4C8E27"),
	Color("#C63B83"),
	Color("#E2A43A"),
	Color("#9D27B9"),
	Color("#555555"),
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
