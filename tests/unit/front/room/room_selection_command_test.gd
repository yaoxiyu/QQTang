extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSelectionCommandScript = preload("res://app/front/room/commands/room_selection_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeRuntime:
	extends Control
	var room_session_controller: Node = Control.new()
	var current_room_entry_context: RoomEntryContext = null
	var current_room_snapshot: RoomSnapshot = null


func test_can_update_selection_rejects_match_room() -> void:
	var command := RoomSelectionCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "casual_match_room"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.can_update_selection(runtime)

	assert_false(bool(result.get("ok", true)), "match room should reject selection updates")
	assert_eq(String(result.get("error_code", "")), "MATCH_ROOM_SELECTION_FORBIDDEN", "match room selection should use stable error code")
	runtime.room_session_controller.free()
	runtime.free()


func test_can_update_selection_accepts_custom_room() -> void:
	var command := RoomSelectionCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "private_room"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.can_update_selection(runtime)

	assert_true(bool(result.get("ok", false)), "custom/private room should allow selection updates")
	runtime.room_session_controller.free()
	runtime.free()
