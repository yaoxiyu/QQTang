extends "res://tests/gut/base/qqt_unit_test.gd"

const PresenterScript = preload("res://scenes/front/room_scene_selector_presenter.gd")


func test_select_metadata_selects_expected_value() -> void:
	var presenter = PresenterScript.new()
	var selector := OptionButton.new()
	selector.add_item("A")
	selector.set_item_metadata(0, "a")
	selector.add_item("B")
	selector.set_item_metadata(1, "b")
	presenter.select_metadata(selector, "b")
	assert_eq(presenter.selected_metadata(selector), "b", "select_metadata should select expected value")

