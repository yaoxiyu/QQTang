class_name GameServiceBattleAllocClient
extends RefCounted

const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

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
	var parsed_url := HttpRequestHelperScript.parse_url(base_url + path)
	if parsed_url.is_empty():
		return _fail("BATTLE_ALLOC_URL_INVALID", "Game service battle alloc url is invalid")

	var body := "" if payload == null else JSON.stringify(payload)
	var method_str := "POST" if method == HTTPClient.METHOD_POST else "GET"
	var headers := _auth_signer.sign_headers(method_str, String(parsed_url["path"]), body)
	var options := HttpRequestOptionsScript.new()
	options.method = method
	options.url = base_url + path
	options.headers = headers
	options.body_text = body
	options.log_tag = LOG_TAG
	options.connect_timeout_ms = 5000
	options.read_timeout_ms = 8000
	LogNetScript.info("battle_alloc_client sending %s body_len=%d" % [path, body.length()], "", 0, LOG_TAG)
	var response = HttpRequestExecutorScript.execute(options)
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("BATTLE_ALLOC_CONNECT_FAILED", "Failed to connect game service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("BATTLE_ALLOC_REQUEST_FAILED", "Failed to send battle alloc request")
	var text := String(response.body_text)
	LogNetScript.info("battle_alloc_client response text=%s" % text.substr(0, 500), "", 0, LOG_TAG)
	if text.strip_edges().is_empty():
		return _fail("BATTLE_ALLOC_EMPTY_RESPONSE", "Game service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("BATTLE_ALLOC_RESPONSE_INVALID", "Game service returned invalid response")
	return _normalize(response.body_json)


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
