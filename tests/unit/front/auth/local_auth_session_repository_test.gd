extends Node

const LocalAuthSessionRepositoryScript = preload("res://app/front/auth/local_auth_session_repository.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const LocalFrontStorageSlotScript = preload("res://app/front/profile/local_front_storage_slot.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var repository = LocalAuthSessionRepositoryScript.new()
	repository.clear_session()
	_clear_device_secret()

	var state := AuthSessionStateScript.new()
	state.login_status = AuthSessionState.LoginStatus.LOGGED_IN
	state.account_id = "account_repo"
	state.profile_id = "profile_repo"
	state.access_token = "access_repo"
	state.refresh_token = "refresh_repo"
	state.device_session_id = "dsess_repo"
	state.access_expire_at_unix_sec = 100
	state.refresh_expire_at_unix_sec = 200
	state.session_state = "active"

	var save_ok := repository.save_session(state)
	var loaded := repository.load_session()
	repository.clear_session()
	var cleared := repository.load_session()

	var prefix := "local_auth_session_repository_test"
	var ok := true
	ok = TestAssert.is_true(save_ok, "save_session should succeed", prefix) and ok
	ok = TestAssert.is_true(String(loaded.account_id) == "account_repo", "load_session should restore account id", prefix) and ok
	ok = TestAssert.is_true(String(loaded.profile_id) == "profile_repo", "load_session should restore profile id", prefix) and ok
	ok = TestAssert.is_true(String(loaded.device_session_id) == "dsess_repo", "load_session should restore device session", prefix) and ok
	ok = TestAssert.is_true(String(cleared.account_id) == "", "clear_session should remove persisted session", prefix) and ok

	if ok:
		print("local_auth_session_repository_test: PASS")


func _clear_device_secret() -> void:
	var save_path := LocalFrontStorageSlotScript.build_save_path("device_secret")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
