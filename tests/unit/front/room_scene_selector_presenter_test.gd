extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSceneSelectorPresenterScript = preload("res://scenes/front/room_scene_selector_presenter.gd")
const RoomTeamPaletteScript = preload("res://app/front/room/room_team_palette.gd")
const TeamColorPaletteLoaderScript = preload("res://content/team_colors/runtime/team_color_palette_loader.gd")


class TestController:
	extends Node
	var team_selector: OptionButton


func test_main() -> void:
	_test_select_metadata_selects_expected_value()
	_test_team_selector_covers_all_palette_teams_even_for_two_team_modes()
	_test_room_team_palette_uses_content_team_colors()


func _test_select_metadata_selects_expected_value() -> void:
	var presenter := RoomSceneSelectorPresenterScript.new()
	var selector := OptionButton.new()
	selector.add_item("A")
	selector.set_item_metadata(0, "a")
	selector.add_item("B")
	selector.set_item_metadata(1, "b")
	presenter.select_metadata(selector, "b")
	_assert_true(presenter.selected_metadata(selector) == "b", "select_metadata should select expected value")


func _test_team_selector_covers_all_palette_teams_even_for_two_team_modes() -> void:
	var presenter := RoomSceneSelectorPresenterScript.new()
	var controller := TestController.new()
	controller.team_selector = OptionButton.new()
	add_child(controller)
	controller.add_child(controller.team_selector)

	presenter.populate_team_selector(controller, 2)
	_assert_true(controller.team_selector.item_count >= 8, "hidden team selector should contain A-H metadata")

	presenter.select_team_id(controller, 8)
	_assert_true(presenter.selected_team_id(controller) == 8, "selecting Team H should update selected team id")

	controller.queue_free()


func _test_room_team_palette_uses_content_team_colors() -> void:
	var palette := TeamColorPaletteLoaderScript.load_palette(RoomTeamPaletteScript.DEFAULT_PALETTE_ID)
	_assert_true(palette != null, "default room team palette should load")
	if palette == null:
		return
	for team_id in RoomTeamPaletteScript.TEAM_IDS:
		var team_color: Dictionary = palette.get_team_color(team_id)
		_assert_true(team_color.has("ui_color"), "team %d should define ui_color" % team_id)
		_assert_true(
			RoomTeamPaletteScript.color_for_team(team_id) == team_color.get("ui_color"),
			"room team %d button color should match content palette" % team_id
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
