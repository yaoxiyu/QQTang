extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomMatchCommandScript = preload("res://app/front/room/commands/room_match_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeController:
	extends Control
	var begin_called := false
	var blocker: Dictionary = {}

	func request_begin_match(_peer_id: int) -> Dictionary:
		begin_called = true
		return {"ok": true}

	func get_start_match_blocker(_peer_id: int) -> Dictionary:
		return blocker.duplicate(true)


class FakeFrontFlow:
	extends RefCounted
	var start_requested := false

	func request_start_match() -> void:
		start_requested = true


class FakeGateway:
	extends RefCounted
	var start_called := false
	var rematch_called := false
	var config_called := false
	var last_format_id := ""
	var last_mode_ids: Array[String] = []

	func request_start_match() -> void:
		start_called = true

	func request_rematch() -> void:
		rematch_called = true

	func request_update_match_room_config(format_id: String, mode_ids: Array[String]) -> void:
		config_called = true
		last_format_id = format_id
		last_mode_ids = mode_ids.duplicate()


class FakeRuntime:
	extends Control
	var local_peer_id := 1
	var current_room_entry_context: RoomEntryContext = null
	var current_room_snapshot: RoomSnapshot = null
	var room_session_controller: Node = null
	var front_flow: RefCounted = null


func test_start_match_rejects_match_room_direct_start() -> void:
	var command := RoomMatchCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	runtime.current_room_entry_context = entry
	runtime.room_session_controller = FakeController.new()

	var result: Dictionary = command.start_match(runtime, null)

	assert_false(bool(result.get("ok", true)), "match rooms should not start directly")
	assert_eq(String(result.get("error_code", "")), "MATCH_ROOM_START_FORBIDDEN", "direct match room start should use stable error code")
	runtime.room_session_controller.free()
	runtime.free()


func test_start_match_local_requests_controller_and_front_flow() -> void:
	var command := RoomMatchCommandScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var front_flow := FakeFrontFlow.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "practice"
	runtime.current_room_entry_context = entry
	runtime.room_session_controller = controller
	runtime.front_flow = front_flow

	var result: Dictionary = command.start_match(runtime, null)

	assert_true(bool(result.get("ok", false)), "local start should succeed")
	assert_true(controller.begin_called, "local start should request controller begin")
	assert_true(front_flow.start_requested, "local start should enter loading through front flow")
	controller.free()
	runtime.free()


func test_online_start_match_requests_gateway_and_stays_pending() -> void:
	var command := RoomMatchCommandScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var gateway := FakeGateway.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "private_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	runtime.room_session_controller = controller

	var result: Dictionary = command.start_match(runtime, gateway)

	assert_true(bool(result.get("ok", false)), "online start should succeed")
	assert_true(bool(result.get("pending", false)), "online start should stay pending")
	assert_true(gateway.start_called, "online start should notify gateway")
	assert_false(controller.begin_called, "online start should not begin local match immediately")
	controller.free()
	runtime.free()


func test_update_match_room_config_requests_gateway() -> void:
	var command := RoomMatchCommandScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeGateway.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "casual_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.update_match_room_config(runtime, gateway, "format_duo", ["mode_a", "mode_b"])

	assert_true(bool(result.get("ok", false)), "match room config update should succeed")
	assert_true(gateway.config_called, "match room config update should notify gateway")
	assert_eq(gateway.last_format_id, "format_duo", "format id should be forwarded")
	assert_eq(gateway.last_mode_ids, ["mode_a", "mode_b"], "mode ids should be forwarded")
	runtime.free()


func test_request_rematch_rejects_match_room() -> void:
	var command := RoomMatchCommandScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeGateway.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry

	var result: Dictionary = command.request_rematch(runtime, gateway)

	assert_false(bool(result.get("ok", true)), "match room should reject rematch")
	assert_eq(String(result.get("error_code", "")), "MATCH_ROOM_REMATCH_FORBIDDEN", "match room rematch should use stable error code")
	runtime.free()
