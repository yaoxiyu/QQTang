class_name GameServiceBattleAllocClient
extends RefCounted

const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")

const MANUAL_ROOM_CREATE_PATH := "/internal/v1/battles/manual-room/create"
const LOG_TAG := "net.battle_alloc"

var base_url: String = ""
var service_token: String = ""
var _auth_signer: InternalAuthSigner = null


func configure(p_base_url: String, p_service_token: String, p_key_id: String = "primary") -> void:
	base_url = p_base_url.strip_edges().trim_suffix("/")
	service_token = p_service_token.strip_edges()
	_auth_signer = InternalAuthSignerScript.new()
	_auth_signer.configure(p_key_id, service_token)
	LogNetScript.info("battle_alloc_client configured base_url=%s token_len=%d" % [base_url, service_token.length()], "", 0, LOG_TAG)


func request_manual_room_battle(request: Dictionary) -> Dictionary:
	return _send_json_request(HTTPClient.METHOD_POST, MANUAL_ROOM_CREATE_PATH, request)


func _send_json_request(method: int, path: String, payload: Variant) -> Dictionary:
	LogNetScript.info("battle_alloc_client request path=%s" % path, "", 0, LOG_TAG)
	if base_url.is_empty():
		return _fail("BATTLE_ALLOC_URL_MISSING", "Game service battle alloc url is missing")
	if _auth_signer == null or service_token.is_empty():
		return _fail("BATTLE_ALLOC_TOKEN_MISSING", "Game service battle alloc token is missing")
	var parsed_url := _parse_url(base_url + path)
	if parsed_url.is_empty():
		return _fail("BATTLE_ALLOC_URL_INVALID", "Game service battle alloc url is invalid")

	var client := HTTPClient.new()
	LogNetScript.info("battle_alloc_client connecting to %s:%d" % [String(parsed_url["host"]), int(parsed_url["port"])], "", 0, LOG_TAG)
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return _fail("BATTLE_ALLOC_CONNECT_FAILED", "Failed to connect game service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _fail("BATTLE_ALLOC_CONNECT_FAILED", "Failed to connect game service")

	var body := "" if payload == null else JSON.stringify(payload)
	var method_str := "POST" if method == HTTPClient.METHOD_POST else "GET"
	var headers := _auth_signer.sign_headers(method_str, String(parsed_url["path"]), body)
	LogNetScript.info("battle_alloc_client sending %s body_len=%d" % [path, body.length()], "", 0, LOG_TAG)
	err = client.request(method, String(parsed_url["path"]), headers, body)
	if err != OK:
		return _fail("BATTLE_ALLOC_REQUEST_FAILED", "Failed to send battle alloc request")

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	var chunks := HttpResponseReaderScript.read_body_bytes(
		client, "net", LOG_TAG, "game_service_battle_alloc_client",
		{"path": path, "method": method}
	)
	var text := chunks.get_string_from_utf8()
	LogNetScript.info("battle_alloc_client response text=%s" % text.substr(0, 500), "", 0, LOG_TAG)
	if text.strip_edges().is_empty():
		return _fail("BATTLE_ALLOC_EMPTY_RESPONSE", "Game service returned empty response")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("BATTLE_ALLOC_RESPONSE_INVALID", "Game service returned invalid response")
	return _normalize(json.data)


func _fail(error_code: String, user_message: String) -> Dictionary:
	LogNetScript.warn("battle_alloc_client FAIL: %s %s" % [error_code, user_message], "", 0, LOG_TAG)
	return {"ok": false, "error_code": error_code, "user_message": user_message}


func _normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _fail("BATTLE_ALLOC_RESPONSE_INVALID", "Invalid response type")
	var result: Dictionary = (value as Dictionary).duplicate(true)
	if not result.has("ok"):
		result["ok"] = result.get("error_code", "") == ""
	if not result.has("error_code"):
		result["error_code"] = ""
	if not result.has("user_message") and result.has("message"):
		result["user_message"] = String(result.get("message", ""))
	if not result.has("user_message"):
		result["user_message"] = ""
	return result


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
