class_name LogoutUseCase
extends RefCounted

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func logout() -> Dictionary:
	if app_runtime == null:
		return {
			"ok": false,
			"error_code": "RUNTIME_MISSING",
			"user_message": "Front runtime is missing",
		}
	var logout_result := {
		"ok": true,
		"error_code": "",
		"user_message": "",
	}
	if app_runtime.auth_gateway != null and app_runtime.auth_gateway.has_method("logout") and app_runtime.auth_session_state != null:
		logout_result = await app_runtime.auth_gateway.logout(
			String(app_runtime.auth_session_state.access_token),
			String(app_runtime.auth_session_state.refresh_token),
			String(app_runtime.auth_session_state.device_session_id)
		)
		if logout_result == null:
			logout_result = {
				"ok": false,
				"error_code": "AUTH_LOGOUT_RESULT_MISSING",
				"user_message": "Logout result is missing",
			}
	if app_runtime.auth_session_state != null:
		app_runtime.auth_session_state.clear()
	if app_runtime.auth_session_repository != null and app_runtime.auth_session_repository.has_method("clear_session"):
		app_runtime.auth_session_repository.clear_session()
	if app_runtime.front_settings_state != null and app_runtime.front_settings_state.has_method("clear_reconnect_ticket"):
		app_runtime.front_settings_state.clear_reconnect_ticket()
		if app_runtime.front_settings_repository != null and app_runtime.front_settings_repository.has_method("save_settings"):
			app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)
	if "current_room_entry_context" in app_runtime:
		app_runtime.current_room_entry_context = null
	return logout_result
