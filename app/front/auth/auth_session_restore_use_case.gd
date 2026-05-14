class_name AuthSessionRestoreUseCase
extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func restore_on_boot() -> Dictionary:
	if app_runtime == null:
		return _error_result("BOOT_RUNTIME_MISSING", "Front runtime is missing")
	_configure_gateways_from_settings()

	var session: AuthSessionState = app_runtime.auth_session_state if app_runtime.auth_session_state != null else AuthSessionStateScript.new()
	if _is_session_empty(session):
		return _login_result()

	var now_unix_sec := Time.get_unix_time_from_system()
	if _is_access_token_usable(session, now_unix_sec):
		var profile_sync := await _try_sync_profile()
		if not bool(profile_sync.get("ok", true)):
			return profile_sync
		return _lobby_result()

	if _is_refresh_token_usable(session, now_unix_sec):
		var refresh_result := await _refresh_session()
		if bool(refresh_result.get("ok", false)):
			var profile_sync := await _try_sync_profile()
			if not bool(profile_sync.get("ok", true)):
				return profile_sync
			return _lobby_result()

		_clear_session()
		return _login_result()

	_clear_session()
	return _login_result()


func _refresh_session() -> Dictionary:
	if app_runtime.auth_gateway == null or not app_runtime.auth_gateway.has_method("refresh_session"):
		return {
			"ok": false,
			"error_code": "AUTH_REFRESH_GATEWAY_MISSING",
			"user_message": "Refresh session gateway is missing",
			"next_route": "login",
		}
	var session: AuthSessionState = app_runtime.auth_session_state
	var result = await app_runtime.auth_gateway.refresh_session(session.refresh_token, session.device_session_id)
	if result == null or not bool(result.ok):
		return {
			"ok": false,
			"error_code": String(result.error_code if result != null else "AUTH_REFRESH_FAILED"),
			"user_message": String(result.user_message if result != null else "Session refresh failed"),
			"next_route": "login",
		}
	_apply_refresh_result(result)
	if app_runtime.auth_session_repository != null and app_runtime.auth_session_repository.has_method("save_session"):
		app_runtime.auth_session_repository.save_session(app_runtime.auth_session_state)
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"next_route": "lobby",
	}


func _apply_refresh_result(result: RefreshSessionResult) -> void:
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


func _try_sync_profile() -> Dictionary:
	if app_runtime.profile_gateway == null:
		return {"ok": true}
	if not app_runtime.profile_gateway.has_method("fetch_my_profile"):
		return {"ok": true}
	var result = await app_runtime.profile_gateway.fetch_my_profile(app_runtime.auth_session_state.access_token)
	if result == null:
		return _error_result("PROFILE_FETCH_RESULT_MISSING", "Profile sync result is missing")
	if not bool(result.get("ok", false)):
		return _error_result(String(result.get("error_code", "PROFILE_FETCH_FAILED")), String(result.get("user_message", "Failed to sync profile")))
	if app_runtime.player_profile_state != null:
		app_runtime.player_profile_state.profile_id = String(result.get("profile_id", app_runtime.auth_session_state.profile_id))
		app_runtime.player_profile_state.account_id = String(result.get("account_id", app_runtime.auth_session_state.account_id))
		app_runtime.player_profile_state.nickname = String(result.get("nickname", app_runtime.auth_session_state.display_name))
		if _has_object_property(app_runtime.player_profile_state, "avatar_id"):
			app_runtime.player_profile_state.avatar_id = String(result.get("avatar_id", app_runtime.player_profile_state.avatar_id))
		if _has_object_property(app_runtime.player_profile_state, "title_id"):
			app_runtime.player_profile_state.title_id = String(result.get("title_id", app_runtime.player_profile_state.title_id))
		app_runtime.player_profile_state.default_character_id = PlayerProfileStateScript.resolve_default_character_id(String(result.get("default_character_id", app_runtime.player_profile_state.default_character_id)))
		app_runtime.player_profile_state.default_bubble_style_id = String(result.get("default_bubble_style_id", app_runtime.player_profile_state.default_bubble_style_id))
		app_runtime.player_profile_state.preferred_map_id = String(result.get("preferred_map_id", app_runtime.player_profile_state.preferred_map_id))
		app_runtime.player_profile_state.preferred_rule_set_id = String(result.get("preferred_rule_set_id", app_runtime.player_profile_state.preferred_rule_set_id))
		app_runtime.player_profile_state.preferred_mode_id = String(result.get("preferred_mode_id", app_runtime.player_profile_state.preferred_mode_id))
		if _has_object_property(app_runtime.player_profile_state, "owned_character_ids"):
			app_runtime.player_profile_state.owned_character_ids = PlayerProfileStateScript._to_string_array(result.get("owned_character_ids", []))
		if _has_object_property(app_runtime.player_profile_state, "owned_bubble_style_ids"):
			app_runtime.player_profile_state.owned_bubble_style_ids = PlayerProfileStateScript._to_string_array(result.get("owned_bubble_style_ids", []))
		if _has_object_property(app_runtime.player_profile_state, "profile_version"):
			app_runtime.player_profile_state.profile_version = int(result.get("profile_version", app_runtime.player_profile_state.profile_version))
		if _has_object_property(app_runtime.player_profile_state, "owned_asset_revision"):
			app_runtime.player_profile_state.owned_asset_revision = int(result.get("owned_asset_revision", app_runtime.player_profile_state.owned_asset_revision))
		if _has_object_property(app_runtime.player_profile_state, "profile_source"):
			app_runtime.player_profile_state.profile_source = "cloud_cache"
		if _has_object_property(app_runtime.player_profile_state, "last_sync_msec"):
			app_runtime.player_profile_state.last_sync_msec = Time.get_ticks_msec()
	if app_runtime.profile_repository != null and app_runtime.profile_repository.has_method("save_profile"):
		app_runtime.profile_repository.save_profile(app_runtime.player_profile_state)
	return {"ok": true}


func _configure_gateways_from_settings() -> void:
	if app_runtime.front_settings_state == null:
		return
	var host := String(app_runtime.front_settings_state.account_service_host).strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(app_runtime.front_settings_state.account_service_port)
	if port <= 0:
		port = 18080
	var base_url := ServiceUrlBuilderScript.build_account_base_url(host, port, 18080)
	if app_runtime.auth_gateway != null and app_runtime.auth_gateway.has_method("configure_base_url"):
		app_runtime.auth_gateway.configure_base_url(base_url)
	if app_runtime.profile_gateway != null and app_runtime.profile_gateway.has_method("configure_base_url"):
		app_runtime.profile_gateway.configure_base_url(base_url)


func _clear_session() -> void:
	if app_runtime.auth_session_state != null:
		app_runtime.auth_session_state.clear()
	if app_runtime.auth_session_repository != null and app_runtime.auth_session_repository.has_method("clear_session"):
		app_runtime.auth_session_repository.clear_session()


func _is_session_empty(session: AuthSessionState) -> bool:
	if session == null:
		return true
	return String(session.account_id).strip_edges().is_empty() and String(session.refresh_token).strip_edges().is_empty()


func _is_access_token_usable(session: AuthSessionState, now_unix_sec: int) -> bool:
	return not String(session.access_token).strip_edges().is_empty() and int(session.access_expire_at_unix_sec) > now_unix_sec


func _is_refresh_token_usable(session: AuthSessionState, now_unix_sec: int) -> bool:
	return not String(session.refresh_token).strip_edges().is_empty() and int(session.refresh_expire_at_unix_sec) > now_unix_sec


func _lobby_result() -> Dictionary:
	return {
		"ok": true,
		"next_route": "lobby",
		"error_code": "",
		"user_message": "",
	}


func _login_result() -> Dictionary:
	return {
		"ok": true,
		"next_route": "login",
		"error_code": "",
		"user_message": "",
	}


func _error_result(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"next_route": "error",
		"error_code": error_code,
		"user_message": user_message,
	}


func _has_object_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for entry in target.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false
