class_name RegisterUseCase
extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func register(request: RegisterRequest) -> Dictionary:
	if app_runtime == null:
		return {
			"ok": false,
			"error_code": "RUNTIME_MISSING",
			"user_message": "Front runtime is missing",
		}
	if app_runtime.auth_gateway == null or not app_runtime.auth_gateway.has_method("register"):
		return {
			"ok": false,
			"error_code": "AUTH_GATEWAY_MISSING",
			"user_message": "Auth gateway is not configured",
		}
	var result = await app_runtime.auth_gateway.register(request)
	if result == null:
		return {
			"ok": false,
			"error_code": "REGISTER_RESULT_MISSING",
			"user_message": "Register result is missing",
		}
	if not bool(result.ok):
		return {
			"ok": false,
			"error_code": String(result.error_code),
			"user_message": String(result.user_message),
		}
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
	if app_runtime.auth_session_repository != null and app_runtime.auth_session_repository.has_method("save_session"):
		app_runtime.auth_session_repository.save_session(app_runtime.auth_session_state)
	if app_runtime.profile_gateway != null and app_runtime.profile_gateway.has_method("configure_base_url"):
		app_runtime.profile_gateway.configure_base_url(ServiceUrlBuilderScript.build_account_base_url(request.server_host, request.server_port, 18080))
	var profile_result := await _fetch_and_apply_profile()
	if not bool(profile_result.get("ok", false)):
		return profile_result
	if app_runtime.profile_repository != null and app_runtime.profile_repository.has_method("save_profile"):
		app_runtime.profile_repository.save_profile(app_runtime.player_profile_state)
	if app_runtime.front_settings_state != null:
		app_runtime.front_settings_state.account_service_host = request.server_host.strip_edges() if not request.server_host.strip_edges().is_empty() else "127.0.0.1"
		app_runtime.front_settings_state.account_service_port = request.server_port if request.server_port > 0 else 18080
		if app_runtime.front_settings_repository != null and app_runtime.front_settings_repository.has_method("save_settings"):
			app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)
	return {
		"ok": true,
		"error_code": "",
		"user_message": String(result.user_message),
	}


func _fetch_and_apply_profile() -> Dictionary:
	if app_runtime.profile_gateway == null or not app_runtime.profile_gateway.has_method("fetch_my_profile"):
		return {
			"ok": true,
			"error_code": "",
			"user_message": "",
		}
	var result = await app_runtime.profile_gateway.fetch_my_profile(app_runtime.auth_session_state.access_token)
	if result == null:
		return {
			"ok": false,
			"error_code": "PROFILE_FETCH_RESULT_MISSING",
			"user_message": "Profile fetch result is missing",
		}
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"error_code": String(result.get("error_code", "PROFILE_FETCH_FAILED")),
			"user_message": String(result.get("user_message", "Failed to fetch profile")),
		}
	if app_runtime.player_profile_state != null:
		app_runtime.player_profile_state.profile_id = String(result.get("profile_id", app_runtime.auth_session_state.profile_id))
		app_runtime.player_profile_state.account_id = String(result.get("account_id", app_runtime.auth_session_state.account_id))
		app_runtime.player_profile_state.nickname = String(result.get("nickname", app_runtime.auth_session_state.display_name))
		app_runtime.player_profile_state.default_character_id = PlayerProfileStateScript.resolve_default_character_id(String(result.get("default_character_id", app_runtime.player_profile_state.default_character_id)))
		app_runtime.player_profile_state.default_bubble_style_id = String(result.get("default_bubble_style_id", app_runtime.player_profile_state.default_bubble_style_id))
		app_runtime.player_profile_state.preferred_map_id = String(result.get("preferred_map_id", app_runtime.player_profile_state.preferred_map_id))
		app_runtime.player_profile_state.preferred_rule_set_id = String(result.get("preferred_rule_set_id", app_runtime.player_profile_state.preferred_rule_set_id))
		app_runtime.player_profile_state.preferred_mode_id = String(result.get("preferred_mode_id", app_runtime.player_profile_state.preferred_mode_id))
		app_runtime.player_profile_state.owned_character_ids = PlayerProfileState._to_string_array(result.get("owned_character_ids", []))
		app_runtime.player_profile_state.owned_bubble_style_ids = PlayerProfileState._to_string_array(result.get("owned_bubble_style_ids", []))
		app_runtime.player_profile_state.profile_version = int(result.get("profile_version", app_runtime.player_profile_state.profile_version))
		app_runtime.player_profile_state.owned_asset_revision = int(result.get("owned_asset_revision", app_runtime.player_profile_state.owned_asset_revision))
		app_runtime.player_profile_state.profile_source = "cloud_cache"
		app_runtime.player_profile_state.last_sync_msec = Time.get_ticks_msec()
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
	}
