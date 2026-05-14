class_name InternalJsonServiceClient
extends RefCounted

const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var base_url: String = ""
var key_id: String = "primary"
var shared_secret: String = ""
var log_tag: String = "http.internal_json"
var _auth_signer: InternalAuthSigner = null


func configure(p_base_url: String, p_key_id: String, p_shared_secret: String, p_log_tag: String) -> void:
	base_url = p_base_url.strip_edges().trim_suffix("/")
	key_id = p_key_id.strip_edges() if not p_key_id.strip_edges().is_empty() else "primary"
	shared_secret = p_shared_secret.strip_edges()
	log_tag = p_log_tag.strip_edges() if not p_log_tag.strip_edges().is_empty() else "http.internal_json"
	_auth_signer = null
	if not shared_secret.is_empty():
		_auth_signer = InternalAuthSignerScript.new()
		_auth_signer.configure(key_id, shared_secret)


func post_json(path: String, payload: Dictionary) -> Dictionary:
	return await _send_json_request(HTTPClient.METHOD_POST, path, payload)


func get_json(path: String) -> Dictionary:
	return await _send_json_request(HTTPClient.METHOD_GET, path, null)


func _send_json_request(method: int, path: String, payload: Variant) -> Dictionary:
	if base_url.is_empty():
		return _fail("INTERNAL_JSON_URL_MISSING", "Internal service url is missing")
	if _auth_signer == null:
		return _fail("INTERNAL_JSON_AUTH_MISSING", "Internal auth is missing")
	var request_url := base_url + _normalize_path(path)
	var parsed_url := HttpRequestHelperScript.parse_url(request_url)
	if parsed_url.is_empty():
		return _fail("INTERNAL_JSON_URL_INVALID", "Internal service url is invalid")
	var body := "" if payload == null else JSON.stringify(payload)
	var method_str := "GET"
	if method == HTTPClient.METHOD_POST:
		method_str = "POST"
	var headers := _auth_signer.sign_headers(method_str, String(parsed_url.get("path", "/")), body)

	var options := HttpRequestOptionsScript.new()
	options.method = method
	options.url = request_url
	options.headers = headers
	options.body_text = body
	options.log_tag = log_tag
	options.connect_timeout_ms = 5000
	options.read_timeout_ms = 8000
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("INTERNAL_JSON_CONNECT_FAILED", "Failed to connect internal service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("INTERNAL_JSON_REQUEST_FAILED", "Failed to send internal request")
	if String(response.body_text).strip_edges().is_empty():
		return _fail("INTERNAL_JSON_EMPTY_RESPONSE", "Internal service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("INTERNAL_JSON_RESPONSE_INVALID", "Internal service returned invalid response")
	var result: Dictionary = (response.body_json as Dictionary).duplicate(true)
	if not result.has("ok"):
		result["ok"] = result.get("error_code", "") == ""
	if not result.has("error_code"):
		result["error_code"] = ""
	if not result.has("user_message") and result.has("message"):
		result["user_message"] = String(result.get("message", ""))
	if not result.has("user_message"):
		result["user_message"] = ""
	result["status_code"] = int(response.status_code)
	return result


func _normalize_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return "/"
	if not normalized.begins_with("/"):
		return "/" + normalized
	return normalized


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
