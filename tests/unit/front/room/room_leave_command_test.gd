extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomLeaveCommandScript = preload("res://app/front/room/commands/room_leave_command.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeGateway:
	extends "res://network/runtime/room_client/room_client_gateway.gd"


class FakeLeaveGateway:
	extends RefCounted
	var connected := true
	var cancel_called := false
	var leave_disconnect_called := false

	func is_transport_connected() -> bool:
		return connected

	func request_cancel_match_queue() -> void:
		cancel_called = true

	func request_leave_room_and_disconnect() -> void:
		leave_disconnect_called = true


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


func test_request_gateway_leave_skips_network_calls_when_transport_disconnected() -> void:
	var command := RoomLeaveCommandScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeLeaveGateway.new()
	gateway.connected = false
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.queue_phase = "queued"
	runtime.current_room_snapshot = snapshot

	command.request_gateway_leave(runtime, gateway, true)

	assert_false(gateway.cancel_called, "disconnected transport should not send queue cancel during leave")
	assert_false(gateway.leave_disconnect_called, "disconnected transport should not send leave request")
	runtime.free()
