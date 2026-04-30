extends "res://tests/gut/base/qqt_contract_test.gd"

const TeamColorPaletteLoaderScript = preload("res://content/team_colors/runtime/team_color_palette_loader.gd")

const EXPECTED_LABELS := {
	1: "A",
	2: "B",
	3: "C",
	4: "D",
	5: "E",
	6: "F",
	7: "G",
	8: "H",
}
const EXPECTED_UI_COLORS := {
	1: Color("#C94124"),
	2: Color("#2E42C8"),
	3: Color("#EFE84A"),
	4: Color("#4C8E27"),
	5: Color("#C63B83"),
	6: Color("#E2A43A"),
	7: Color("#9D27B9"),
	8: Color("#555555"),
}


func test_main() -> void:
	var palette := TeamColorPaletteLoaderScript.load_palette("team_palette_default_8")
	_assert_true(palette != null, "loads default 8-team palette")
	if palette == null:
		return
	for team_id in range(1, 9):
		_assert_true(palette.has_team(team_id), "default palette contains team_id %d" % team_id)
		var team_color: Dictionary = palette.get_team_color(team_id)
		_assert_true(team_color.has("primary"), "team %d has primary color" % team_id)
		_assert_true(team_color.has("secondary"), "team %d has secondary color" % team_id)
		_assert_true(team_color.get("label") == EXPECTED_LABELS[team_id], "team %d label should match A-H order" % team_id)
		_assert_true(team_color.get("primary") == EXPECTED_UI_COLORS[team_id], "team %d primary color should match QQTang A-H palette" % team_id)
		_assert_true(team_color.get("ui_color") == EXPECTED_UI_COLORS[team_id], "team %d ui color should match QQTang A-H palette" % team_id)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
