extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomProfileCommandScript = preload("res://app/front/room/commands/room_profile_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


class FakeController:
	extends Control
	var last_team_id := -1
	var update_called := false

	func request_update_member_profile(
		_peer_id: int,
		_player_name: String,
		_character_id: String,
		_bubble_style_id: String,
		team_id: int
	) -> Dictionary:
		update_called = true
		last_team_id = team_id
		return {"ok": true}


class FakeGateway:
	extends RefCounted
	var connected := true
	var update_called := false
	var last_team_id := -1

	func is_transport_connected() -> bool:
		return connected

	func request_update_profile(
		_player_name: String,
		_character_id: String,
		_bubble_style_id: String,
		team_id: int
	) -> void:
		update_called = true
		last_team_id = team_id


class FakeRuntime:
	extends Control
	var local_peer_id := 7
	var current_room_entry_context: RoomEntryContext = null
	var current_room_snapshot: RoomSnapshot = null
	var room_session_controller: Node = null


func test_update_local_profile_rejects_missing_controller() -> void:
	var command := RoomProfileCommandScript.new()
	var runtime := FakeRuntime.new()

	var result: Dictionary = command.update_local_profile(runtime, null, "p", "c", "b", 1)

	assert_false(bool(result.get("ok", true)), "missing controller should reject profile update")
	assert_eq(String(result.get("error_code", "")), "ROOM_CONTROLLER_MISSING", "profile command should use stable error code")
	runtime.free()


func test_update_local_profile_uses_locked_match_room_team_and_sends_gateway() -> void:
	var command := RoomProfileCommandScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var gateway := FakeGateway.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	entry.assigned_team_id = 2
	runtime.current_room_entry_context = entry
	runtime.room_session_controller = controller

	var result: Dictionary = command.update_local_profile(runtime, gateway, "p", "c", "b", 1)

	assert_true(bool(result.get("ok", false)), "profile update should succeed")
	assert_eq(controller.last_team_id, 2, "match room profile update should use locked team")
	assert_true(gateway.update_called, "online profile update should notify gateway")
	assert_eq(gateway.last_team_id, 2, "gateway profile update should use locked team")
	controller.free()
	runtime.free()


func test_update_local_profile_rejects_when_online_transport_disconnected() -> void:
	var command := RoomProfileCommandScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var gateway := FakeGateway.new()
	gateway.connected = false
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "private_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	runtime.room_session_controller = controller

	var result: Dictionary = command.update_local_profile(runtime, gateway, "p", "c", "b", 1)

	assert_false(bool(result.get("ok", true)), "online profile update should reject when transport disconnected")
	assert_eq(String(result.get("error_code", "")), "ROOM_NOT_CONNECTED", "disconnected transport should use stable error code")
	assert_false(controller.update_called, "disconnected transport should not mutate local profile state")
	assert_false(gateway.update_called, "disconnected transport should not notify gateway")
	controller.free()
	runtime.free()
