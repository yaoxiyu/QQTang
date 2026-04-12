extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.auth_session_state.account_id = "account_logout"
	runtime.auth_session_state.profile_id = "profile_logout"
	runtime.auth_session_state.access_token = "access_logout"
	runtime.auth_session_state.refresh_token = "refresh_logout"
	runtime.front_settings_state.reconnect_room_id = "room_logout"
	runtime.front_settings_state.reconnect_member_id = "member_logout"
	runtime.front_settings_state.reconnect_token = "token_logout"
	runtime.front_settings_state.reconnect_match_id = "match_logout"

	var logout_result: Dictionary = runtime.lobby_use_case.logout()
	var resume_result: Dictionary = runtime.lobby_use_case.resume_recent_room()

	var prefix := "rejected_resume_after_logout_test"
	var ok := true
	ok = TestAssert.is_true(bool(logout_result.get("ok", false)), "logout should succeed", prefix) and ok
	ok = TestAssert.is_true(not bool(resume_result.get("ok", true)), "resume should fail after logout", prefix) and ok
	ok = TestAssert.is_true(String(resume_result.get("error_code", "")) == "RECONNECT_ROOM_MISSING", "resume should fail because reconnect state was cleared", prefix) and ok

	runtime.queue_free()
	if ok:
		print("rejected_resume_after_logout_test: PASS")
	test_finished.emit()
