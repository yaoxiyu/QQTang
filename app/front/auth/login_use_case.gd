class_name LoginUseCase
extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")

var auth_gateway: AuthGateway = null
var auth_session_state: AuthSessionState = null
var profile_repository: ProfileRepository = null
var front_settings_repository: FrontSettingsRepository = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null


func configure(
	p_auth_gateway: AuthGateway,
	p_auth_session_state: AuthSessionState,
	p_profile_repository: ProfileRepository,
	p_front_settings_repository: FrontSettingsRepository,
	p_player_profile_state: PlayerProfileState,
	p_front_settings_state: FrontSettingsState
) -> void:
	auth_gateway = p_auth_gateway
	auth_session_state = p_auth_session_state if p_auth_session_state != null else AuthSessionStateScript.new()
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

	_apply_profile_from_request(request)
	_apply_settings_from_request(request)
	_apply_auth_session(result)

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


func _apply_profile_from_request(request: LoginRequest) -> void:
	if request == null:
		return
	player_profile_state.profile_id = request.profile_id.strip_edges()
	player_profile_state.nickname = request.nickname.strip_edges()
	player_profile_state.default_character_id = request.default_character_id.strip_edges()
	player_profile_state.default_character_skin_id = request.default_character_skin_id.strip_edges()
	player_profile_state.default_bubble_style_id = request.default_bubble_style_id.strip_edges()
	player_profile_state.default_bubble_skin_id = request.default_bubble_skin_id.strip_edges()


func _apply_settings_from_request(request: LoginRequest) -> void:
	if request == null:
		return
	front_settings_state.last_server_host = request.server_host.strip_edges()
	front_settings_state.last_server_port = request.server_port


func _apply_auth_session(result: LoginResult) -> void:
	auth_session_state.login_status = AuthSessionState.LoginStatus.LOGGED_IN
	auth_session_state.account_id = result.account_id
	auth_session_state.display_name = result.display_name
	auth_session_state.auth_mode = result.auth_mode
	auth_session_state.access_token = ""
	auth_session_state.refresh_token = ""
	auth_session_state.validation_bypassed = result.validation_bypassed
