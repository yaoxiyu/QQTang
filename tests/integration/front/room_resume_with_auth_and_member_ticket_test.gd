extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")



class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_resume_alpha"
		result.ticket_id = "ticket_id_resume_alpha"
		result.account_id = "account_alpha"
		result.profile_id = "profile_alpha"
		result.device_session_id = "dsess_alpha"
		result.room_id = String(request.room_id)
		result.requested_match_id = String(request.requested_match_id)
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
	runtime.front_settings_state.reconnect_room_id = "ROOM_RESUME_001"
	runtime.front_settings_state.reconnect_host = "127.0.0.1"
	runtime.front_settings_state.reconnect_port = 9000
	runtime.front_settings_state.reconnect_room_kind = "private_room"
	runtime.front_settings_state.reconnect_room_display_name = "Room Resume"
	runtime.front_settings_state.reconnect_member_id = "member_alpha"
	runtime.front_settings_state.reconnect_token = "resume_token_alpha"
	runtime.front_settings_state.reconnect_match_id = "match_alpha"
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

	var resume_result: Dictionary = runtime.lobby_use_case.resume_recent_room()
	var entry_context = resume_result.get("entry_context", null)
	var room_result: Dictionary = runtime.room_use_case.enter_room(entry_context)

	var prefix := "room_resume_with_auth_and_member_ticket_test"
	var ok := true
	ok = qqt_check(bool(resume_result.get("ok", false)), "resume_recent_room should succeed", prefix) and ok
	ok = qqt_check(entry_context != null and bool(entry_context.use_resume_flow), "entry context should enable resume flow", prefix) and ok
	ok = qqt_check(entry_context != null and String(entry_context.reconnect_member_id) == "member_alpha", "entry context should keep member id", prefix) and ok
	ok = qqt_check(entry_context != null and String(entry_context.room_ticket) == "ticket_resume_alpha", "entry context should include resume ticket", prefix) and ok
	ok = qqt_check(bool(room_result.get("pending", false)), "resume room should enter pending flow", prefix) and ok
	ok = qqt_check(runtime.room_use_case._pending_connection_config != null, "pending config should exist", prefix) and ok
	if runtime.room_use_case._pending_connection_config != null:
		ok = qqt_check(String(runtime.room_use_case._pending_connection_config.room_ticket) == "ticket_resume_alpha", "pending config should carry resume ticket", prefix) and ok
		ok = qqt_check(String(runtime.room_use_case._pending_connection_config.account_id) == "account_alpha", "pending config should carry account id", prefix) and ok
		ok = qqt_check(String(runtime.room_use_case._pending_connection_config.device_session_id) == "dsess_alpha", "pending config should carry device session", prefix) and ok

	runtime.queue_free()


