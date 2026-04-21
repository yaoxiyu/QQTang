extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_VIEW_MODEL_BUILDER_PATH := "res://app/front/room/room_view_model_builder.gd"
const ROOM_USE_CASE_PATH := "res://app/front/room/room_use_case.gd"


func test_room_view_model_builder_formal_path_uses_capability_instead_of_state_whitelist() -> void:
	var text := _read_text(ROOM_VIEW_MODEL_BUILDER_PATH)
	assert_false(text.is_empty(), "room_view_model_builder.gd should be readable")

	var build_section := _extract_function_block(text, "func build_view_model(", "func _resolve_room_kind(")
	assert_false(build_section.is_empty(), "build_view_model function block should be found")
	assert_true(
		build_section.find("var can_enter_queue := bool(safe_snapshot.can_enter_queue)") >= 0,
		"build_view_model formal path must consume snapshot capability can_enter_queue"
	)
	assert_true(
		build_section.find("var can_cancel_queue := bool(safe_snapshot.can_cancel_queue)") >= 0,
		"build_view_model formal path must consume snapshot capability can_cancel_queue"
	)
	assert_true(
		build_section.find("_can_enter_match_queue(") < 0 and build_section.find("_can_enter_queue_from_state(") < 0,
		"build_view_model formal path must not call whitelist helper functions"
	)
	assert_true(
		text.find("func _can_enter_queue_from_state(") < 0 and text.find("func _can_enter_match_queue(") < 0,
		"room_view_model_builder.gd must not keep legacy enter-queue whitelist helpers"
	)
	assert_true(
		text.find("normalized == \"cancelled\"") < 0 and
		text.find("normalized == \"failed\"") < 0 and
		text.find("normalized == \"expired\"") < 0 and
		text.find("normalized == \"finalized\"") < 0,
		"terminal queue aliases must not be treated as enter-queue sources"
	)


func test_room_use_case_leave_room_cancel_gate_uses_canonical_queue_phase() -> void:
	var text := _read_text(ROOM_USE_CASE_PATH)
	assert_false(text.is_empty(), "room_use_case.gd should be readable")

	var leave_section := _extract_function_block(text, "func leave_room()", "func update_local_profile(")
	assert_false(leave_section.is_empty(), "leave_room function block should be found")
	assert_true(
		leave_section.find("RoomUseCaseRuntimeStateScript.can_cancel_current_queue(app_runtime)") >= 0,
		"leave_room should use canonical queue-phase gate helper for cancel decision"
	)
	assert_true(
		leave_section.find("queueing") < 0,
		"leave_room should not depend on legacy queueing raw string"
	)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _extract_function_block(text: String, begin_marker: String, end_marker: String) -> String:
	var begin := text.find(begin_marker)
	if begin < 0:
		return ""
	var end := text.find(end_marker, begin + begin_marker.length())
	if end < 0:
		end = text.length()
	return text.substr(begin, end - begin)
