extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")



class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_join_alpha"
		result.ticket_id = "ticket_id_join_alpha"
		result.account_id = "account_alpha"
		result.profile_id = "profile_alpha"
		result.device_session_id = "dsess_alpha"
		result.room_id = String(request.room_id)
		return result


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.room_ticket_gateway = FakeRoomTicketGateway.new()
	runtime.auth_session_state.access_token = "access_alpha"
	runtime.auth_session_state.account_id = "account_alpha"
	runtime.auth_session_state.profile_id = "profile_alpha"
	runtime.auth_session_state.device_session_id = "dsess_alpha"
	runtime.player_profile_state.nickname = "PlayerAlpha"
	runtime.player_profile_state.default_character_id = "character_default"
	runtime.player_profile_state.default_bubble_style_id = "bubble_style_default"
	runtime.lobby_use_case.configure(
		runtime,
		runtime.auth_session_state,
		runtime.player_profile_state,
		runtime.front_settings_state,
		runtime.practice_room_factory,
		runtime.auth_session_repository,
		runtime.logout_use_case,
		runtime.profile_gateway,
		runtime.room_ticket_gateway
	)

	var join_result: Dictionary = await runtime.lobby_use_case.join_private_room("127.0.0.1", 9100, "ROOM_JOIN_001")
	var entry_context = join_result.get("entry_context", null)
	var room_result: Dictionary = runtime.room_use_case.enter_room(entry_context)

	var prefix := "room_join_with_ticket_test"
	var ok := true
	ok = qqt_check(bool(join_result.get("ok", false)), "join_private_room should succeed", prefix) and ok
	ok = qqt_check(entry_context != null and String(entry_context.target_room_id) == "ROOM_JOIN_001", "entry context should keep target room id", prefix) and ok
	ok = qqt_check(entry_context != null and String(entry_context.room_ticket) == "ticket_join_alpha", "entry context should include join ticket", prefix) and ok
	ok = qqt_check(bool(room_result.get("pending", false)), "online join should enter pending room flow", prefix) and ok
	ok = qqt_check(runtime.room_use_case._pending_connection_config != null, "pending connection config should exist", prefix) and ok
	if runtime.room_use_case._pending_connection_config != null:
		ok = qqt_check(String(runtime.room_use_case._pending_connection_config.room_id_hint) == "ROOM_JOIN_001", "pending config should preserve room id", prefix) and ok
		ok = qqt_check(String(runtime.room_use_case._pending_connection_config.room_ticket) == "ticket_join_alpha", "pending config should carry join ticket", prefix) and ok

	runtime.queue_free()


