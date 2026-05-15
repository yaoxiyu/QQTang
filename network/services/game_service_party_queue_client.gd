class_name GameServicePartyQueueClient
extends RefCounted

const ResultScript = preload("res://network/services/game_service_party_queue_result.gd")
const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

const ENTER_PATH := "/internal/v1/matchmaking/party-queue/enter"
const CANCEL_PATH := "/internal/v1/matchmaking/party-queue/cancel"
const STATUS_PATH := "/internal/v1/matchmaking/party-queue/status"

var base_url: String = ""
var service_token: String = ""
var _auth_signer: InternalAuthSigner = null


func configure(p_base_url: String, p_service_token: String, p_key_id: String = "primary") -> void:
	base_url = p_base_url.strip_edges().trim_suffix("/")
	service_token = p_service_token.strip_edges()
	_auth_signer = InternalAuthSignerScript.new()
	_auth_signer.configure(p_key_id, service_token)
	LogNetScript.info("party_queue_client configured base_url=%s token_len=%d" % [base_url, service_token.length()], "", 0, "net.party_queue")


func enter_party_queue(request: Dictionary) -> Dictionary:
	return await _send_json_request(HTTPClient.METHOD_POST, ENTER_PATH, request)


func cancel_party_queue(party_room_id: String, queue_entry_id: String) -> Dictionary:
	return await _send_json_request(HTTPClient.METHOD_POST, CANCEL_PATH, {
		"party_room_id": party_room_id,
		"queue_entry_id": queue_entry_id,
	})


func get_party_queue_status(party_room_id: String, queue_entry_id: String) -> Dictionary:
	var query := "?party_room_id=%s&queue_entry_id=%s" % [
		party_room_id.uri_encode(),
		queue_entry_id.uri_encode(),
	]
	return await _send_json_request(HTTPClient.METHOD_GET, STATUS_PATH + query, null)


func _send_json_request(method: int, path: String, payload: Variant) -> Dictionary:
	LogNetScript.info("party_queue_client request path=%s base_url=%s token_len=%d" % [path, base_url, service_token.length()], "", 0, "net.party_queue")
	if base_url.is_empty():
		LogNetScript.warn("party_queue_client FAIL: base_url is empty", "", 0, "net.party_queue")
		return ResultScript.fail("PARTY_QUEUE_URL_MISSING", "Game service party queue url is missing")
	if _auth_signer == null or service_token.is_empty():
		LogNetScript.warn("party_queue_client FAIL: auth signer not configured", "", 0, "net.party_queue")
		return ResultScript.fail("PARTY_QUEUE_SERVICE_TOKEN_MISSING", "Game service party queue token is missing")
	var parsed_url := HttpRequestHelperScript.parse_url(base_url + path)
	if parsed_url.is_empty():
		LogNetScript.warn("party_queue_client FAIL: parsed_url is empty for %s%s" % [base_url, path], "", 0, "net.party_queue")
		return ResultScript.fail("PARTY_QUEUE_URL_INVALID", "Game service party queue url is invalid")

	var body := "" if payload == null else JSON.stringify(payload)
	var method_str := "POST" if method == HTTPClient.METHOD_POST else "GET"
	var headers := _auth_signer.sign_headers(method_str, String(parsed_url["path"]), body)
	var options := HttpRequestOptionsScript.new()
	options.method = method
	options.url = base_url + path
	options.headers = headers
	options.body_text = body
	options.log_tag = "net.party_queue"
	LogNetScript.info("party_queue_client sending %s body_len=%d" % [path, body.length()], "", 0, "net.party_queue")
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		LogNetScript.warn("party_queue_client FAIL: connect failed", "", 0, "net.party_queue")
		return ResultScript.fail("PARTY_QUEUE_CONNECT_FAILED", "Failed to connect game service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		LogNetScript.warn("party_queue_client FAIL: request failed", "", 0, "net.party_queue")
		return ResultScript.fail("PARTY_QUEUE_REQUEST_FAILED", "Failed to send party queue request")
	var text := String(response.body_text)
	LogNetScript.info("party_queue_client response text=%s" % text.substr(0, 500), "", 0, "net.party_queue")
	if text.strip_edges().is_empty():
		return ResultScript.fail("PARTY_QUEUE_EMPTY_RESPONSE", "Game service returned empty party queue response")
	if not (response.body_json is Dictionary):
		return ResultScript.fail("PARTY_QUEUE_RESPONSE_INVALID", "Game service returned invalid party queue response")
	return ResultScript.normalize(response.body_json)
