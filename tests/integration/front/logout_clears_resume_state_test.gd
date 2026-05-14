extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	runtime.auth_session_state.account_id = "account_logout"
	runtime.auth_session_state.profile_id = "profile_logout"
	runtime.auth_session_state.access_token = "access_logout"
	runtime.auth_session_state.refresh_token = "refresh_logout"
	runtime.auth_session_state.device_session_id = "dsess_logout"
	runtime.front_settings_state.reconnect_room_id = "room_logout"
	runtime.front_settings_state.reconnect_member_id = "member_logout"
	runtime.front_settings_state.reconnect_token = "token_logout"
	runtime.front_settings_state.reconnect_state = "active_match"

	var entry_context := RoomEntryContextScript.new()
	entry_context.target_room_id = "room_logout"
	entry_context.account_id = "account_logout"
	entry_context.profile_id = "profile_logout"
	entry_context.reconnect_member_id = "member_logout"
	runtime.current_room_entry_context = entry_context

	var result: Dictionary = await runtime.lobby_use_case.logout()

	var prefix := "logout_clears_resume_state_test"
	var ok := true
	ok = qqt_check(bool(result.get("ok", false)), "logout should succeed", prefix) and ok
	ok = qqt_check(String(runtime.auth_session_state.account_id) == "", "logout should clear account id", prefix) and ok
	ok = qqt_check(String(runtime.auth_session_state.refresh_token) == "", "logout should clear refresh token", prefix) and ok
	ok = qqt_check(String(runtime.front_settings_state.reconnect_room_id) == "", "logout should clear reconnect room id", prefix) and ok
	ok = qqt_check(String(runtime.front_settings_state.reconnect_member_id) == "", "logout should clear reconnect member id", prefix) and ok
	ok = qqt_check(String(runtime.front_settings_state.reconnect_token) == "", "logout should clear reconnect token", prefix) and ok
	ok = qqt_check(runtime.current_room_entry_context == null, "logout should clear current room entry context", prefix) and ok

	runtime.queue_free()
