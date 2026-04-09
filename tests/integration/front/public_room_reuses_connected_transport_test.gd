extends Node

const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")
const LobbyUseCaseScript = preload("res://app/front/lobby/lobby_use_case.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


class FakeClientRoomRuntime:
	extends Node

	signal transport_connected()
	signal room_snapshot_received(snapshot)
	signal room_error(error_code, user_message)
	signal canonical_start_config_received(config)

	var connected_host: String = "127.0.0.1"
	var connected_port: int = 9000
	var connected: bool = true
	var create_requests: Array[Dictionary] = []
	var connect_requests: Array[Dictionary] = []

	func connect_to_server(host: String, port: int, timeout_sec: float = 5.0) -> void:
		connect_requests.append({
			"host": host,
			"port": port,
			"timeout_sec": timeout_sec,
		})

	func is_connected_to(host: String, port: int) -> bool:
		return connected and connected_host == host and connected_port == port

	func is_transport_connected() -> bool:
		return connected

	func request_create_room(
		room_id_hint: String,
		player_name: String,
		character_id: String,
		character_skin_id: String = "",
		bubble_style_id: String = "",
		bubble_skin_id: String = "",
		map_id: String = "",
		rule_set_id: String = "",
		mode_id: String = "",
		room_kind: String = "private_room",
		room_display_name: String = ""
	) -> void:
		create_requests.append({
			"room_id_hint": room_id_hint,
			"player_name": player_name,
			"character_id": character_id,
			"character_skin_id": character_skin_id,
			"bubble_style_id": bubble_style_id,
			"bubble_skin_id": bubble_skin_id,
			"map_id": map_id,
			"rule_set_id": rule_set_id,
			"mode_id": mode_id,
			"room_kind": room_kind,
			"room_display_name": room_display_name,
		})


class FakeAppRuntime:
	extends Node

	var client_room_runtime: Node = null
	var room_session_controller: Node = null
	var current_room_entry_context = null
	var current_room_snapshot = null
	var player_profile_state = null
	var front_settings_state = null
	var front_flow = null
	var local_peer_id: int = 1


class FakeRoomSessionController:
	extends Node

	func reset_room_state() -> void:
		pass

	func set_last_error(_error_code: String, _user_message: String, _details: Dictionary = {}) -> void:
		pass


class FakeFrontFlow:
	extends Node

	var enter_room_called: bool = false

	func enter_room() -> void:
		enter_room_called = true


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var ok := _test_public_room_create_reuses_existing_transport()
	if ok:
		print("public_room_reuses_connected_transport_test: PASS")
	test_finished.emit()


func _test_public_room_create_reuses_existing_transport() -> bool:
	var app_runtime := FakeAppRuntime.new()
	var client_runtime := FakeClientRoomRuntime.new()
	var room_controller := FakeRoomSessionController.new()
	var front_flow := FakeFrontFlow.new()
	var player_profile := PlayerProfileStateScript.new()
	player_profile.nickname = "RuntimeTester"
	var front_settings := FrontSettingsStateScript.new()
	front_settings.last_server_host = "127.0.0.1"
	front_settings.last_server_port = 9000

	app_runtime.client_room_runtime = client_runtime
	app_runtime.room_session_controller = room_controller
	app_runtime.player_profile_state = player_profile
	app_runtime.front_settings_state = front_settings
	app_runtime.front_flow = front_flow

	add_child(app_runtime)
	app_runtime.add_child(client_runtime)
	app_runtime.add_child(room_controller)
	app_runtime.add_child(front_flow)

	var lobby_use_case = LobbyUseCaseScript.new()
	lobby_use_case.configure(null, player_profile, front_settings, null)
	var room_use_case = RoomUseCaseScript.new()
	room_use_case.configure(app_runtime)

	var create_result: Dictionary = lobby_use_case.create_public_room("127.0.0.1", 9000, "Alpha Room")
	var room_result: Dictionary = room_use_case.enter_room(create_result.get("entry_context", null))

	var prefix := "public_room_reuses_connected_transport_test"
	var ok := true
	ok = TestAssert.is_true(bool(room_result.get("pending", false)), "reused transport path should still report pending", prefix) and ok
	ok = TestAssert.is_true(client_runtime.connect_requests.is_empty(), "reused transport path should not reconnect transport", prefix) and ok
	ok = TestAssert.is_true(client_runtime.create_requests.size() == 1, "reused transport path should dispatch create request immediately", prefix) and ok
	ok = TestAssert.is_true(String(client_runtime.create_requests[0].get("room_kind", "")) == "public_room", "create request should preserve public room kind", prefix) and ok
	ok = TestAssert.is_true(String(client_runtime.create_requests[0].get("room_display_name", "")) == "Alpha Room", "create request should preserve room display name", prefix) and ok

	app_runtime.queue_free()
	return ok
