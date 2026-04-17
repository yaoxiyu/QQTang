extends Node

const PresenterScript = preload("res://scenes/front/room_scene_selector_presenter.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var prefix := "room_scene_selector_presenter_test"
	var presenter = PresenterScript.new()
	var selector := OptionButton.new()
	selector.add_item("A")
	selector.set_item_metadata(0, "a")
	selector.add_item("B")
	selector.set_item_metadata(1, "b")
	presenter.select_metadata(selector, "b")
	var ok := true
	ok = TestAssert.is_true(presenter.selected_metadata(selector) == "b", "select_metadata should select expected value", prefix) and ok
	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)
