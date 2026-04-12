class_name LoginUseCase
extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")

var auth_gateway: AuthGateway = null
var auth_session_state: AuthSessionState = null
var auth_session_repository: RefCounted = null
var profile_gateway: RefCounted = null
var profile_repository: ProfileRepository = null
var front_settings_repository: FrontSettingsRepository = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null


func configure(
	p_auth_gateway: AuthGateway,
	p_auth_session_state: AuthSessionState,
	p_auth_session_repository: RefCounted,
	p_profile_gateway: RefCounted,
	p_profile_repository: ProfileRepository,
	p_front_settings_repository: FrontSettingsRepository,
	p_player_profile_state: PlayerProfileState,
	p_front_settings_state: FrontSettingsState
) -> void:
	auth_gateway = p_auth_gateway
	auth_session_state = p_auth_session_state if p_auth_session_state != null else AuthSessionStateScript.new()
	auth_session_repository = p_auth_session_repository
	profile_gateway = p_profile_gateway
	profile_repository = p_profile_repository
	front_settings_repository = p_front_settings_repository
	player_profile_state = p_player_profile_state if p_player_profile_state != null else PlayerProfileStateScript.new()
	front_settings_state = p_front_settings_state if p_front_settings_state != null else FrontSettingsStateScript.new()


func login(request: LoginRequest) -> Dictionary:
	if auth_gateway == null:
		return {
			"ok": false,
			"error_code": "AUTH_GATEWAY_MISSING",
			"user_message": "Auth gateway is not configured",
		}

	var result := auth_gateway.login(request)
	if result == null:
		return {
			"ok": false,
			"error_code": "LOGIN_RESULT_MISSING",
			"user_message": "Login result is missing",
		}
	if not result.ok:
		return {
			"ok": false,
			"error_code": result.error_code,
			"user_message": result.user_message,
		}

	_apply_settings_from_request(request)
	_apply_auth_session(result)
	if auth_session_repository != null and auth_session_repository.has_method("save_session") and not auth_session_repository.save_session(auth_session_state):
		return {
			"ok": false,
			"error_code": "AUTH_SESSION_SAVE_FAILED",
			"user_message": "Failed to save auth session",
		}

	var profile_result := _fetch_and_apply_profile()
	if not bool(profile_result.get("ok", false)):
		return profile_result

	if profile_repository != null and not profile_repository.save_profile(player_profile_state):
		return {
			"ok": false,
			"error_code": "PROFILE_SAVE_FAILED",
			"user_message": "Failed to save player profile",
		}
	if front_settings_repository != null and not front_settings_repository.save_settings(front_settings_state):
		return {
			"ok": false,
			"error_code": "FRONT_SETTINGS_SAVE_FAILED",
			"user_message": "Failed to save front settings",
		}

	return {
		"ok": true,
		"error_code": "",
		"user_message": result.user_message,
	}


func _apply_settings_from_request(request: LoginRequest) -> void:
	if request == null:
		return
	front_settings_state.last_server_host = request.server_host.strip_edges()
	front_settings_state.last_server_port = request.server_port


func _apply_auth_session(result: LoginResult) -> void:
	auth_session_state.login_status = AuthSessionState.LoginStatus.LOGGED_IN
	auth_session_state.account_id = result.account_id
	auth_session_state.profile_id = result.profile_id
	auth_session_state.display_name = result.display_name
	auth_session_state.auth_mode = result.auth_mode
	auth_session_state.access_token = result.access_token
	auth_session_state.refresh_token = result.refresh_token
	auth_session_state.device_session_id = result.device_session_id
	auth_session_state.access_expire_at_unix_sec = result.access_expire_at_unix_sec
	auth_session_state.refresh_expire_at_unix_sec = result.refresh_expire_at_unix_sec
	auth_session_state.session_state = result.session_state
	auth_session_state.validation_bypassed = result.validation_bypassed


func _fetch_and_apply_profile() -> Dictionary:
	if profile_gateway == null or not profile_gateway.has_method("fetch_my_profile"):
		player_profile_state.profile_id = auth_session_state.profile_id
		player_profile_state.nickname = auth_session_state.display_name
		return {
			"ok": true,
			"error_code": "",
			"user_message": "",
		}
	var result = profile_gateway.fetch_my_profile(auth_session_state.access_token)
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
	player_profile_state.profile_id = String(result.get("profile_id", auth_session_state.profile_id))
	player_profile_state.account_id = String(result.get("account_id", auth_session_state.account_id))
	player_profile_state.nickname = String(result.get("nickname", auth_session_state.display_name))
	player_profile_state.default_character_id = String(result.get("default_character_id", player_profile_state.default_character_id))
	player_profile_state.default_character_skin_id = String(result.get("default_character_skin_id", player_profile_state.default_character_skin_id))
	player_profile_state.default_bubble_style_id = String(result.get("default_bubble_style_id", player_profile_state.default_bubble_style_id))
	player_profile_state.default_bubble_skin_id = String(result.get("default_bubble_skin_id", player_profile_state.default_bubble_skin_id))
	player_profile_state.preferred_map_id = String(result.get("preferred_map_id", player_profile_state.preferred_map_id))
	player_profile_state.preferred_rule_set_id = String(result.get("preferred_rule_set_id", player_profile_state.preferred_rule_set_id))
	player_profile_state.preferred_mode_id = String(result.get("preferred_mode_id", player_profile_state.preferred_mode_id))
	player_profile_state.owned_character_ids = PlayerProfileStateScript._to_string_array(result.get("owned_character_ids", []))
	player_profile_state.owned_character_skin_ids = PlayerProfileStateScript._to_string_array(result.get("owned_character_skin_ids", []))
	player_profile_state.owned_bubble_style_ids = PlayerProfileStateScript._to_string_array(result.get("owned_bubble_style_ids", []))
	player_profile_state.owned_bubble_skin_ids = PlayerProfileStateScript._to_string_array(result.get("owned_bubble_skin_ids", []))
	player_profile_state.profile_version = int(result.get("profile_version", player_profile_state.profile_version))
	player_profile_state.owned_asset_revision = int(result.get("owned_asset_revision", player_profile_state.owned_asset_revision))
	player_profile_state.profile_source = "cloud_cache"
	player_profile_state.last_sync_msec = Time.get_ticks_msec()
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
	}
