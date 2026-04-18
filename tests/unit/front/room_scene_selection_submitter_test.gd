extends "res://tests/gut/base/qqt_unit_test.gd"

const SubmitterScript = preload("res://scenes/front/room_scene_selection_submitter.gd")

class FakeUseCase:
	extends RefCounted
	var called: bool = false
	func update_match_room_config(_format_id: String, _mode_ids: Array[String]) -> Dictionary:
		called = true
		return {"ok": true}

class FakeController:
	extends "res://tests/gut/base/qqt_unit_test.gd"
	var _suppress_selection_callbacks: bool = false
	var _room_use_case = FakeUseCase.new()
	var match_format_selector: OptionButton = null
	func _selected_metadata(_selector) -> String:
		return "1v1"
	func _selected_match_mode_ids() -> Array[String]:
		return ["classic"]
	func _set_room_feedback(_message: String) -> void:
		pass


func test_main() -> void:
	var prefix := "room_scene_selection_submitter_test"
	var submitter = SubmitterScript.new()
	var controller := FakeController.new()
	submitter.on_match_mode_multi_select_changed(controller)
	var ok := qqt_check(controller._room_use_case.called, "submitter should call use case on mode multi-select change", prefix)

