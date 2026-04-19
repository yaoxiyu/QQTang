extends "res://tests/gut/base/qqt_integration_test.gd"

const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")
const LobbyUseCaseScript = preload("res://app/front/lobby/lobby_use_case.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")



class FakeClientRoomRuntime:
	extends "res://tests/gut/base/qqt_integration_test.gd"

	signal transport_connected()
	signal room_snapshot_received(snapshot)
	signal room_error(error_code, user_message)
	signal canonical_start_config_received(config)

	var connected_host: String = "127.0.0.1"
	var connected_port: int = 9100
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
		room_display_name: String = "",
		room_ticket: String = "",
		room_ticket_id: String = "",
		account_id: String = "",
		profile_id: String = "",
		device_session_id: String = ""
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
			"room_ticket": room_ticket,
			"room_ticket_id": room_ticket_id,
			"account_id": account_id,
			"profile_id": profile_id,
			"device_session_id": device_session_id,
		})


class FakeAppRuntime:
	extends "res://tests/gut/base/qqt_integration_test.gd"

	var client_room_runtime: Node = null
	var room_session_controller: Node = null
	var current_room_entry_context = null
	var current_room_snapshot = null
	var player_profile_state = null
	var front_settings_state = null
	var front_flow = null
	var auth_session_state = null
	var local_peer_id: int = 1


class FakeRoomSessionController:
	extends "res://tests/gut/base/qqt_integration_test.gd"

	func reset_room_state() -> void:
		pass

	func set_last_error(_error_code: String, _user_message: String, _details: Dictionary = {}) -> void:
		pass


class FakeFrontFlow:
	extends "res://tests/gut/base/qqt_integration_test.gd"

	var enter_room_called: bool = false

	func enter_room() -> void:
		enter_room_called = true


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_alpha"
		result.ticket_id = "ticket_id_alpha"
		result.account_id = "account_alpha"
		result.profile_id = "profile_alpha"
		result.device_session_id = "device_session_alpha"
		return result


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	_test_public_room_create_reuses_existing_transport()


func _test_public_room_create_reuses_existing_transport() -> bool:
	var app_runtime := FakeAppRuntime.new()
	var client_runtime := FakeClientRoomRuntime.new()
	var room_controller := FakeRoomSessionController.new()
	var front_flow := FakeFrontFlow.new()
	var auth_session := AuthSessionStateScript.new()
	auth_session.access_token = "access_token_alpha"
	auth_session.device_session_id = "device_session_alpha"
	auth_session.account_id = "account_alpha"
	auth_session.profile_id = "profile_alpha"
	var player_profile := PlayerProfileStateScript.new()
	player_profile.nickname = "RuntimeTester"
	player_profile.account_id = "account_alpha"
	player_profile.profile_id = "profile_alpha"
	var front_settings := FrontSettingsStateScript.new()
	front_settings.last_server_host = "127.0.0.1"
	front_settings.last_server_port = 9100

	app_runtime.client_room_runtime = client_runtime
	app_runtime.room_session_controller = room_controller
	app_runtime.player_profile_state = player_profile
	app_runtime.front_settings_state = front_settings
	app_runtime.front_flow = front_flow
	app_runtime.auth_session_state = auth_session

	add_child(app_runtime)
	app_runtime.add_child(client_runtime)
	app_runtime.add_child(room_controller)
	app_runtime.add_child(front_flow)

	var fake_room_ticket_gateway := FakeRoomTicketGateway.new()

	var lobby_use_case = LobbyUseCaseScript.new()
	lobby_use_case.configure(app_runtime, auth_session, player_profile, front_settings, null, null, null, null, fake_room_ticket_gateway)
	var room_use_case = RoomUseCaseScript.new()
	room_use_case.configure(app_runtime)
	var gateway = room_use_case.get("room_client_gateway")

	var create_result: Dictionary = lobby_use_case.create_public_room("127.0.0.1", 9100, "Alpha Room")
	var room_result: Dictionary = room_use_case.enter_room(create_result.get("entry_context", null))
	if client_runtime.create_requests.is_empty():
		room_use_case.call("_on_gateway_transport_connected")
	var pending_entry = room_use_case.get("_pending_online_entry_context")
	var pending_config = room_use_case.get("_pending_connection_config")

	var prefix := "public_room_reuses_connected_transport_test"
	var ok := true
	ok = qqt_check(bool(room_result.get("pending", false)), "reused transport path should still report pending: %s" % JSON.stringify(room_result), prefix) and ok
	ok = qqt_check(gateway != null, "room gateway should be initialized", prefix) and ok
	ok = qqt_check(gateway != null and gateway.get("client_room_runtime") != null, "room gateway should bind fake runtime", prefix) and ok
	ok = qqt_check(client_runtime.connect_requests.is_empty(), "reused transport path should not reconnect transport", prefix) and ok
	var create_dispatched_or_deferred := client_runtime.create_requests.size() == 1 or (
		pending_entry != null and String(pending_entry.entry_kind) == FrontEntryKindScript.ONLINE_CREATE
	)
	ok = qqt_check(
		create_dispatched_or_deferred,
		"reused transport path should dispatch or keep deferred create create=%d connect=%d entry=%s cfg=%s create_result=%s" % [
			client_runtime.create_requests.size(),
			client_runtime.connect_requests.size(),
			JSON.stringify(pending_entry.to_dict() if pending_entry != null and pending_entry.has_method("to_dict") else {}),
			JSON.stringify(pending_config.to_dict() if pending_config != null and pending_config.has_method("to_dict") else {}),
			JSON.stringify(create_result)
		],
		prefix
	) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("room_kind", "")) == "public_room", "create request should preserve public room kind", prefix) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("room_display_name", "")) == "Alpha Room", "create request should preserve room display name", prefix) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("room_ticket", "")) == "ticket_alpha", "create request should include room ticket", prefix) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("account_id", "")) == "account_alpha", "create request should include account id", prefix) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("profile_id", "")) == "profile_alpha", "create request should include profile id", prefix) and ok
	ok = qqt_check(String(client_runtime.create_requests[0].get("device_session_id", "")) == "device_session_alpha", "create request should include device session id", prefix) and ok

	app_runtime.queue_free()
	return ok



