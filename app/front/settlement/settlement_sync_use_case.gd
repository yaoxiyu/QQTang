class_name SettlementSyncUseCase
extends RefCounted

const SettlementSummaryStateScript = preload("res://app/front/settlement/settlement_summary_state.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")
const ONLINE_LOG_PREFIX := "[ONLINE]"

var auth_session_state: AuthSessionState = null
var front_settings_state: FrontSettingsState = null
var settlement_gateway: RefCounted = null
var current_summary: SettlementSummaryState = null


func configure(
	p_auth_session_state: AuthSessionState,
	p_front_settings_state: FrontSettingsState,
	p_settlement_gateway: RefCounted
) -> void:
	auth_session_state = p_auth_session_state
	front_settings_state = p_front_settings_state
	settlement_gateway = p_settlement_gateway


func fetch_match_summary(match_id: String) -> Dictionary:
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if settlement_gateway == null:
		return _fail("SETTLEMENT_GATEWAY_MISSING", "Settlement gateway is not available")
	_configure_gateway()
	_log_settlement("fetch_match_summary_requested", {
		"match_id": match_id,
	})
	var response = await settlement_gateway.fetch_match_summary(auth_session_state.access_token, match_id)
	if not bool(response.get("ok", false)):
		_log_settlement("fetch_match_summary_failed", {
			"match_id": match_id,
			"error_code": String(response.get("error_code", "SETTLEMENT_FETCH_FAILED")),
			"user_message": String(response.get("user_message", "Failed to fetch settlement summary")),
		})
		return _fail(String(response.get("error_code", "SETTLEMENT_FETCH_FAILED")), String(response.get("user_message", "Failed to fetch settlement summary")))
	current_summary = SettlementSummaryStateScript.from_response(response)
	_log_settlement("fetch_match_summary_succeeded", {
		"match_id": current_summary.match_id if current_summary != null else match_id,
		"server_sync_state": current_summary.server_sync_state if current_summary != null else "",
		"rating_delta": current_summary.rating_delta if current_summary != null else 0,
		"season_point_delta": current_summary.season_point_delta if current_summary != null else 0,
	})
	return {
		"ok": true,
		"summary": current_summary,
	}


func apply_summary_to_popup(summary) -> Dictionary:
	if summary == null:
		return _fail("SETTLEMENT_SUMMARY_MISSING", "Settlement summary is missing")
	if summary is SettlementSummaryState:
		_log_settlement("apply_summary_to_popup_state", {
			"match_id": summary.match_id,
			"server_sync_state": summary.server_sync_state,
		})
		return {
			"ok": true,
			"popup_summary": summary.to_popup_summary(),
		}
	if summary is Dictionary:
		_log_settlement("apply_summary_to_popup_dict", {
			"keys": summary.keys(),
		})
		return {
			"ok": true,
			"popup_summary": summary,
		}
	return _fail("SETTLEMENT_SUMMARY_INVALID", "Settlement summary is invalid")


func _configure_gateway() -> void:
	if front_settings_state == null:
		return
	if settlement_gateway != null and settlement_gateway.has_method("configure_base_url"):
		settlement_gateway.configure_base_url(ServiceUrlBuilderScript.build_game_base_url(front_settings_state.game_service_host, front_settings_state.game_service_port, 18081))


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}


func _log_settlement(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[settlement_sync_use_case] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.settlement.use_case")
