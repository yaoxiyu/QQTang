class_name CareerUseCase
extends RefCounted

const LobbyViewStateScript = preload("res://app/front/lobby/lobby_view_state.gd")
const CareerSummaryStateScript = preload("res://app/front/career/career_summary_state.gd")

var auth_session_state: AuthSessionState = null
var front_settings_state: FrontSettingsState = null
var career_gateway: RefCounted = null
var current_summary: CareerSummaryState = null


func configure(
	p_auth_session_state: AuthSessionState,
	p_front_settings_state: FrontSettingsState,
	p_career_gateway: RefCounted
) -> void:
	auth_session_state = p_auth_session_state
	front_settings_state = p_front_settings_state
	career_gateway = p_career_gateway


func refresh_career_summary() -> Dictionary:
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if career_gateway == null:
		return _fail("CAREER_GATEWAY_MISSING", "Career gateway is not available")
	_configure_gateway()
	var response = career_gateway.fetch_my_career(auth_session_state.access_token)
	if not bool(response.get("ok", false)):
		return _fail(String(response.get("error_code", "CAREER_FETCH_FAILED")), String(response.get("user_message", "Failed to fetch career summary")))
	current_summary = CareerSummaryStateScript.from_response(response)
	return {
		"ok": true,
		"summary": current_summary,
	}


func build_lobby_career_view_model() -> LobbyViewState:
	var view_state := LobbyViewStateScript.new()
	if current_summary == null:
		return view_state
	view_state.current_season_id = current_summary.current_season_id
	view_state.current_rating = current_summary.current_rating
	view_state.current_rank_tier = current_summary.current_rank_tier
	view_state.career_total_matches = current_summary.career_total_matches
	view_state.career_total_wins = current_summary.career_total_wins
	view_state.career_total_losses = current_summary.career_total_losses
	view_state.career_total_draws = current_summary.career_total_draws
	view_state.career_win_rate_bp = current_summary.career_win_rate_bp
	return view_state


func get_current_summary() -> CareerSummaryState:
	return current_summary


func _configure_gateway() -> void:
	if front_settings_state == null:
		return
	if career_gateway != null and career_gateway.has_method("configure_base_url"):
		career_gateway.configure_base_url("http://%s:%d" % [front_settings_state.game_service_host, front_settings_state.game_service_port])


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
