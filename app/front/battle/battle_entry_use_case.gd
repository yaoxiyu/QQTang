class_name BattleEntryUseCase
extends RefCounted

## Orchestrates the battle entry flow:
## 1. Build BattleEntryContext from authoritative RoomSnapshot fields
## 2. Request battle ticket from account_service
## 3. Supply context for battle_ds connection and scene transition

const RoomBattleEntryBuilderScript = preload("res://app/front/room/room_battle_entry_builder.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")
const BATTLE_ENTRY_LOG_PREFIX := "[BATTLE_ENTRY]"

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func build_battle_entry_context(snapshot: RoomSnapshot):
	var room_entry_context = app_runtime.current_room_entry_context if app_runtime != null else null
	var ctx = RoomBattleEntryBuilderScript.build(snapshot, room_entry_context)
	if ctx == null:
		return null

	_log_battle_entry("battle_entry_context_built", ctx.to_dict())
	return ctx


func request_battle_ticket(ctx) -> Dictionary:
	if ctx == null or not ctx.is_valid():
		return {"ok": false, "error_code": "BATTLE_ENTRY_CONTEXT_INVALID", "user_message": "Battle entry context is missing or invalid"}
	if app_runtime == null:
		return {"ok": false, "error_code": "APP_RUNTIME_MISSING", "user_message": "App runtime is not configured"}

	var access_token := _resolve_access_token()
	if access_token.is_empty():
		return {"ok": false, "error_code": "ACCESS_TOKEN_MISSING", "user_message": "Not authenticated"}

	var base_url := _resolve_account_service_base_url()
	if base_url.is_empty():
		return {"ok": false, "error_code": "ACCOUNT_SERVICE_URL_MISSING", "user_message": "Account service URL is not configured"}

	var url := base_url + "/api/v1/tickets/battle-entry"
	var body := JSON.stringify({
		"assignment_id": ctx.assignment_id,
		"battle_id": ctx.battle_id,
	})

	_log_battle_entry("battle_ticket_request_started", {
		"assignment_id": ctx.assignment_id,
		"battle_id": ctx.battle_id,
		"url": url,
	})

	var result := _http_post_json(url, access_token, body)
	if not bool(result.get("ok", false)):
		_log_battle_entry("battle_ticket_request_failed", {
			"error_code": String(result.get("error_code", "")),
			"user_message": String(result.get("user_message", "")),
		})
		return {"ok": false, "error_code": String(result.get("error_code", "")), "user_message": String(result.get("user_message", ""))}

	var response: Dictionary = result.get("data", {})
	ctx.battle_ticket = String(response.get("ticket", ""))
	ctx.battle_ticket_id = String(response.get("ticket_id", ""))

	# Also read match_id from grant response if available
	if ctx.match_id.is_empty():
		ctx.match_id = String(response.get("match_id", ""))

	_log_battle_entry("battle_ticket_acquired", {
		"ticket_id": ctx.battle_ticket_id,
		"battle_id": ctx.battle_id,
		"assignment_id": ctx.assignment_id,
		"match_id": ctx.match_id,
	})

	return {"ok": true, "error_code": "", "user_message": ""}


func _resolve_access_token() -> String:
	if app_runtime == null or app_runtime.auth_session_state == null:
		return ""
	return String(app_runtime.auth_session_state.access_token)


func _resolve_account_service_base_url() -> String:
	if app_runtime == null:
		return ""
	var host := "127.0.0.1"
	var port := 18080
	if "front_settings_state" in app_runtime and app_runtime.front_settings_state != null:
		var settings = app_runtime.front_settings_state
		if "account_service_host" in settings and not String(settings.account_service_host).strip_edges().is_empty():
			host = String(settings.account_service_host).strip_edges()
		if "account_service_port" in settings and int(settings.account_service_port) > 0:
			port = int(settings.account_service_port)
	return "http://%s:%d" % [host, port]


func _http_post_json(url: String, access_token: String, body: String) -> Dictionary:
	var parsed := HttpRequestHelperScript.parse_url(url)
	if parsed.is_empty():
		return {"ok": false, "error_code": "INVALID_URL", "user_message": "Invalid URL: %s" % url, "data": {}}
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_POST
	options.url = url
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	options.body_text = body
	options.log_tag = "front.battle.entry_use_case"
	options.connect_timeout_ms = 5000
	options.read_timeout_ms = 8000
	var response = HttpRequestExecutorScript.execute(options)
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return {"ok": false, "error_code": "CONNECT_FAILED", "user_message": "Failed to connect to account service", "data": {}}
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return {"ok": false, "error_code": "REQUEST_FAILED", "user_message": "Failed to send battle ticket request", "data": {}}
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return {"ok": false, "error_code": "EMPTY_RESPONSE", "user_message": "Account service returned empty response", "data": {}}
	if not (response.body_json is Dictionary):
		return {"ok": false, "error_code": "INVALID_RESPONSE", "user_message": "Account service returned invalid response", "data": {}}

	var data: Dictionary = response.body_json
	if not bool(data.get("ok", false)):
		var err_code := String(data.get("error_code", "BATTLE_TICKET_REQUEST_FAILED"))
		var err_msg := String(data.get("user_message", data.get("message", "Battle ticket request failed")))
		return {"ok": false, "error_code": err_code, "user_message": err_msg, "data": data}

	return {"ok": true, "error_code": "", "user_message": "", "data": data}


func _log_battle_entry(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[battle_entry] %s %s" % [BATTLE_ENTRY_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.battle.entry")
