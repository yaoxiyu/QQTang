extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomReadyCommandScript = preload("res://app/front/room/commands/room_ready_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeController:
	extends Control
	var toggle_called := false

	func request_toggle_ready(_peer_id: int) -> Dictionary:
		toggle_called = true
		return {"ok": true}


class FakeGateway:
	extends RefCounted
	var connected := true
	var toggle_called := false

	func is_transport_connected() -> bool:
		return connected

	func request_toggle_ready() -> void:
		toggle_called = true


class FakeRuntime:
	extends Control
	var local_peer_id := 1
	var room_session_controller: Node = FakeController.new()
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


func test_can_toggle_ready_rejects_match_room() -> void:
	var command := RoomReadyCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.can_toggle_ready(runtime)

	assert_false(bool(result.get("ok", true)), "match room should reject manual ready")
	assert_eq(String(result.get("error_code", "")), "MATCH_ROOM_READY_LOCKED", "match room ready should use stable error code")
	runtime.room_session_controller.free()
	runtime.free()


func test_can_toggle_ready_prefers_authoritative_custom_room_snapshot() -> void:
	var command := RoomReadyCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	var snapshot := RoomSnapshot.new()
	snapshot.room_kind = "private_room"
	runtime.current_room_entry_context = entry
	runtime.current_room_snapshot = snapshot

	var result: Dictionary = command.can_toggle_ready(runtime)

	assert_true(bool(result.get("ok", false)), "authoritative custom room snapshot should allow manual ready")
	runtime.room_session_controller.free()
	runtime.free()


func test_toggle_ready_rejects_when_online_transport_disconnected() -> void:
	var command := RoomReadyCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "private_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	var gateway := FakeGateway.new()
	gateway.connected = false
	var controller: FakeController = runtime.room_session_controller

	var result: Dictionary = command.toggle_ready(runtime, gateway)

	assert_false(bool(result.get("ok", true)), "online ready should reject when transport disconnected")
	assert_eq(String(result.get("error_code", "")), "ROOM_NOT_CONNECTED", "disconnected transport should use stable error code")
	assert_false(controller.toggle_called, "disconnected transport should not mutate local ready state")
	assert_false(gateway.toggle_called, "disconnected transport should not notify gateway")
	runtime.room_session_controller.free()
	runtime.free()
