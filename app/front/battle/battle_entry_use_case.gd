class_name BattleEntryUseCase
extends RefCounted

## Phase23: Orchestrates the battle entry flow:
## 1. Build BattleEntryContext from RoomSnapshot Phase23 fields
## 2. Request battle ticket from account_service
## 3. Supply context for battle_ds connection and scene transition

const BattleEntryContextScript = preload("res://app/front/battle/battle_entry_context.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const PHASE23_LOG_PREFIX := "[QQT_P23]"

var app_runtime: Node = null


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime


func build_battle_entry_context(snapshot: RoomSnapshot):
	if snapshot == null:
		return null
	if not snapshot.battle_entry_ready:
		return null
	if snapshot.current_assignment_id.is_empty() or snapshot.current_battle_id.is_empty():
		return null
	if snapshot.battle_server_host.is_empty() or snapshot.battle_server_port <= 0:
		return null

	var ctx = BattleEntryContextScript.new()
	ctx.assignment_id = snapshot.current_assignment_id
	ctx.battle_id = snapshot.current_battle_id
	ctx.map_id = snapshot.selected_map_id
	ctx.rule_set_id = snapshot.rule_set_id
	ctx.mode_id = snapshot.mode_id
	ctx.battle_server_host = snapshot.battle_server_host
	ctx.battle_server_port = snapshot.battle_server_port
	ctx.room_return_policy = snapshot.room_return_policy

	# Populate source room info for return flow
	ctx.source_room_id = snapshot.room_id
	ctx.source_room_kind = snapshot.room_kind
	if app_runtime != null and app_runtime.current_room_entry_context != null:
		ctx.source_server_host = app_runtime.current_room_entry_context.server_host
		ctx.source_server_port = app_runtime.current_room_entry_context.server_port

	_log_phase23("battle_entry_context_built", ctx.to_dict())
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

	_log_phase23("battle_ticket_request_started", {
		"assignment_id": ctx.assignment_id,
		"battle_id": ctx.battle_id,
		"url": url,
	})

	var result := _http_post_json(url, access_token, body)
	if not bool(result.get("ok", false)):
		_log_phase23("battle_ticket_request_failed", {
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

	_log_phase23("battle_ticket_acquired", {
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
	var parsed := _parse_url(url)
	if parsed.is_empty():
		return {"ok": false, "error_code": "INVALID_URL", "user_message": "Invalid URL: %s" % url, "data": {}}

	var client := HTTPClient.new()
	var err := client.connect_to_host(String(parsed["host"]), int(parsed["port"]))
	if err != OK:
		return {"ok": false, "error_code": "CONNECT_FAILED", "user_message": "Failed to connect to account service", "data": {}}

	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"ok": false, "error_code": "CONNECT_FAILED", "user_message": "Failed to connect to account service", "data": {}}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	err = client.request(HTTPClient.METHOD_POST, String(parsed["path"]), headers, body)
	if err != OK:
		return {"ok": false, "error_code": "REQUEST_FAILED", "user_message": "Failed to send battle ticket request", "data": {}}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"front",
		"front.battle.entry_use_case",
		"battle_entry_use_case",
		{"url": url, "method": HTTPClient.METHOD_POST}
	)
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return {"ok": false, "error_code": "EMPTY_RESPONSE", "user_message": "Account service returned empty response", "data": {}}

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"ok": false, "error_code": "INVALID_RESPONSE", "user_message": "Account service returned invalid response", "data": {}}

	var response: Dictionary = json.data
	if not bool(response.get("ok", false)):
		var err_code := String(response.get("error_code", "BATTLE_TICKET_REQUEST_FAILED"))
		var err_msg := String(response.get("user_message", response.get("message", "Battle ticket request failed")))
		return {"ok": false, "error_code": err_code, "user_message": err_msg, "data": response}

	return {"ok": true, "error_code": "", "user_message": "", "data": response}


func _parse_url(url: String) -> Dictionary:
	var normalized := url.strip_edges()
	if not normalized.begins_with("http://"):
		return {}
	var without_scheme := normalized.substr(7)
	var slash_index := without_scheme.find("/")
	var host_port := without_scheme
	var path := "/"
	if slash_index >= 0:
		host_port = without_scheme.substr(0, slash_index)
		path = without_scheme.substr(slash_index, without_scheme.length() - slash_index)
	var colon_index := host_port.rfind(":")
	if colon_index <= 0 or colon_index >= host_port.length() - 1:
		return {}
	return {
		"host": host_port.substr(0, colon_index),
		"port": int(host_port.substr(colon_index + 1, host_port.length() - colon_index - 1)),
		"path": path,
	}


func _log_phase23(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[battle_entry] %s %s" % [PHASE23_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.battle.entry")
