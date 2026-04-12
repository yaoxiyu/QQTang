extends Node

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var state := AuthSessionStateScript.new()
	state.login_status = AuthSessionState.LoginStatus.LOGGED_IN
	state.account_id = "account_alpha"
	state.profile_id = "profile_alpha"
	state.display_name = "Alpha"
	state.auth_mode = "account"
	state.access_token = "access_alpha"
	state.refresh_token = "refresh_alpha"
	state.device_session_id = "dsess_alpha"
	state.access_expire_at_unix_sec = 123
	state.refresh_expire_at_unix_sec = 456
	state.session_state = "active"
	state.validation_bypassed = false

	var restored := AuthSessionStateScript.from_dict(state.to_dict())
	var cleared := restored.duplicate_deep()
	cleared.clear()

	var prefix := "auth_session_state_test"
	var ok := true
	ok = TestAssert.is_true(String(restored.account_id) == "account_alpha", "to_dict/from_dict should preserve account id", prefix) and ok
	ok = TestAssert.is_true(String(restored.profile_id) == "profile_alpha", "to_dict/from_dict should preserve profile id", prefix) and ok
	ok = TestAssert.is_true(String(restored.device_session_id) == "dsess_alpha", "to_dict/from_dict should preserve device session", prefix) and ok
	ok = TestAssert.is_true(int(restored.access_expire_at_unix_sec) == 123, "to_dict/from_dict should preserve access expire", prefix) and ok
	ok = TestAssert.is_true(int(restored.refresh_expire_at_unix_sec) == 456, "to_dict/from_dict should preserve refresh expire", prefix) and ok
	ok = TestAssert.is_true(String(cleared.account_id) == "", "clear should reset account id", prefix) and ok
	ok = TestAssert.is_true(String(cleared.profile_id) == "", "clear should reset profile id", prefix) and ok
	ok = TestAssert.is_true(String(cleared.device_session_id) == "", "clear should reset device session", prefix) and ok
	ok = TestAssert.is_true(int(cleared.access_expire_at_unix_sec) == 0, "clear should reset access expire", prefix) and ok
	ok = TestAssert.is_true(String(cleared.session_state) == "logged_out", "clear should reset session state", prefix) and ok

	if ok:
		print("auth_session_state_test: PASS")
