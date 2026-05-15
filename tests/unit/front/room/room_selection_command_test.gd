extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSelectionCommandScript = preload("res://app/front/room/commands/room_selection_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeController:
	extends Control
	var update_called := false

	func request_update_selection(_peer_id: int, _map_id: String, _rule_id: String, _mode_id: String) -> Dictionary:
		update_called = true
		return {"ok": true}


class FakeGateway:
	extends RefCounted
	var connected := true
	var update_called := false

	func is_transport_connected() -> bool:
		return connected

	func request_update_selection(_map_id: String, _rule_id: String, _mode_id: String) -> void:
		update_called = true


class FakeRuntime:
	extends Control
	var local_peer_id := 1
	var room_session_controller: Node = FakeController.new()
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


func test_update_selection_rejects_when_online_transport_disconnected() -> void:
	var command := RoomSelectionCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "private_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	var gateway := FakeGateway.new()
	gateway.connected = false
	var controller: FakeController = runtime.room_session_controller

	var result: Dictionary = command.update_selection(runtime, gateway, "map_a", "rule_a", "mode_a")

	assert_false(bool(result.get("ok", true)), "online selection update should reject when transport disconnected")
	assert_eq(String(result.get("error_code", "")), "ROOM_NOT_CONNECTED", "disconnected transport should use stable error code")
	assert_false(controller.update_called, "disconnected transport should not mutate local selection state")
	assert_false(gateway.update_called, "disconnected transport should not notify gateway")
	runtime.room_session_controller.free()
	runtime.free()
