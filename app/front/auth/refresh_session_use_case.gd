class_name RefreshSessionUseCase
extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func refresh_session() -> Dictionary:
	if app_runtime == null:
		return {
			"ok": false,
			"error_code": "RUNTIME_MISSING",
			"user_message": "Front runtime is missing",
		}
	if app_runtime.auth_gateway == null or not app_runtime.auth_gateway.has_method("refresh_session"):
		return {
			"ok": false,
			"error_code": "AUTH_REFRESH_GATEWAY_MISSING",
			"user_message": "Refresh session gateway is missing",
		}
	var session: AuthSessionState = app_runtime.auth_session_state if app_runtime.auth_session_state != null else AuthSessionStateScript.new()
	var result = app_runtime.auth_gateway.refresh_session(session.refresh_token, session.device_session_id)
	if result == null:
		return {
			"ok": false,
			"error_code": "AUTH_REFRESH_RESULT_MISSING",
			"user_message": "Refresh session result is missing",
		}
	if not bool(result.ok):
		return {
			"ok": false,
			"error_code": String(result.error_code),
			"user_message": String(result.user_message),
		}
	_apply_result(result)
	if app_runtime.auth_session_repository != null and app_runtime.auth_session_repository.has_method("save_session"):
		app_runtime.auth_session_repository.save_session(app_runtime.auth_session_state)
	return {
		"ok": true,
		"error_code": "",
		"user_message": String(result.user_message),
	}


func _apply_result(result: RefreshSessionResult) -> void:
	if app_runtime.auth_session_state == null:
		app_runtime.auth_session_state = AuthSessionStateScript.new()
	app_runtime.auth_session_state.login_status = AuthSessionState.LoginStatus.LOGGED_IN
	app_runtime.auth_session_state.account_id = result.account_id
	app_runtime.auth_session_state.profile_id = result.profile_id
	app_runtime.auth_session_state.display_name = result.display_name
	app_runtime.auth_session_state.auth_mode = result.auth_mode
	app_runtime.auth_session_state.access_token = result.access_token
	app_runtime.auth_session_state.refresh_token = result.refresh_token
	app_runtime.auth_session_state.device_session_id = result.device_session_id
	app_runtime.auth_session_state.access_expire_at_unix_sec = result.access_expire_at_unix_sec
	app_runtime.auth_session_state.refresh_expire_at_unix_sec = result.refresh_expire_at_unix_sec
	app_runtime.auth_session_state.session_state = result.session_state
	app_runtime.auth_session_state.validation_bypassed = result.validation_bypassed
