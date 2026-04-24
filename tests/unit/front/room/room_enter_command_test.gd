extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomEnterCommandScript = preload("res://app/front/room/commands/room_enter_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


func test_can_enter_rejects_missing_runtime() -> void:
	var command := RoomEnterCommandScript.new()
	var context := RoomEntryContextScript.new()

	var result := command.can_enter(null, context)

	assert_false(bool(result.get("ok", true)), "missing runtime should reject enter")
	assert_eq(String(result.get("error_code", "")), "APP_RUNTIME_MISSING", "missing runtime should use stable error code")


func test_can_enter_rejects_missing_entry_context() -> void:
	var command := RoomEnterCommandScript.new()
	var runtime := Node.new()

	var result := command.can_enter(runtime, null)
	runtime.free()

	assert_false(bool(result.get("ok", true)), "missing context should reject enter")
	assert_eq(String(result.get("error_code", "")), "ROOM_ENTRY_CONTEXT_MISSING", "missing context should use stable error code")


func test_dedicated_non_practice_uses_online_room() -> void:
	var command := RoomEnterCommandScript.new()
	var context := RoomEntryContextScript.new()
	context.topology = FrontTopologyScript.DEDICATED_SERVER
	context.room_kind = FrontRoomKindScript.PRIVATE_ROOM

	assert_true(command.should_use_online_dedicated_room(context), "dedicated non-practice room should use online path")


func test_dedicated_practice_does_not_use_online_room() -> void:
	var command := RoomEnterCommandScript.new()
	var context := RoomEntryContextScript.new()
	context.topology = FrontTopologyScript.DEDICATED_SERVER
	context.room_kind = FrontRoomKindScript.PRACTICE

	assert_false(command.should_use_online_dedicated_room(context), "practice room should stay local even with dedicated topology")
