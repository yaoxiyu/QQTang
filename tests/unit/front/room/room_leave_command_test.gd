extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomLeaveCommandScript = preload("res://app/front/room/commands/room_leave_command.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeGateway:
	extends "res://network/runtime/room_client/room_client_gateway.gd"


class FakeRuntime:
	extends Control
	var current_room_snapshot: RoomSnapshot = null
	var current_room_entry_context: RoomEntryContext = null
	var room_session_controller: Node = null


func test_can_leave_rejects_missing_runtime() -> void:
	var command := RoomLeaveCommandScript.new()

	var result: Dictionary = command.can_leave(null)

	assert_false(bool(result.get("ok", true)), "missing runtime should reject leave")
	assert_eq(String(result.get("error_code", "")), "APP_RUNTIME_MISSING", "missing runtime should use stable error code")


func test_should_cancel_queue_on_leave_for_online_match_room() -> void:
	var command := RoomLeaveCommandScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeGateway.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.queue_phase = "queued"
	runtime.current_room_snapshot = snapshot

	assert_true(command.should_cancel_queue_on_leave(runtime, gateway, true), "online queued match room should cancel queue on leave")
	runtime.free()
