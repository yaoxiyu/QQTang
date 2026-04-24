extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomReadyCommandScript = preload("res://app/front/room/commands/room_ready_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeRuntime:
	extends Control
	var room_session_controller: Node = Control.new()
	var current_room_entry_context: RoomEntryContext = null
	var current_room_snapshot: RoomSnapshot = null


func test_can_toggle_ready_rejects_missing_controller() -> void:
	var command := RoomReadyCommandScript.new()
	var runtime := FakeRuntime.new()
	var controller := runtime.room_session_controller
	runtime.room_session_controller = null

	var result: Dictionary = command.can_toggle_ready(runtime)

	assert_false(bool(result.get("ok", true)), "missing controller should reject ready")
	assert_eq(String(result.get("error_code", "")), "ROOM_CONTROLLER_MISSING", "missing controller should use stable error code")
	controller.free()
	runtime.free()


func test_can_toggle_ready_rejects_matchmade_room() -> void:
	var command := RoomReadyCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "matchmade_room"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.can_toggle_ready(runtime)

	assert_false(bool(result.get("ok", true)), "matchmade room should reject manual ready")
	assert_eq(String(result.get("error_code", "")), "MATCHMADE_READY_LOCKED", "matchmade ready should use stable error code")
	runtime.room_session_controller.free()
	runtime.free()
