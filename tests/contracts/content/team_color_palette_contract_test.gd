extends "res://tests/gut/base/qqt_contract_test.gd"

const TeamColorPaletteLoaderScript = preload("res://content/team_colors/runtime/team_color_palette_loader.gd")


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


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
