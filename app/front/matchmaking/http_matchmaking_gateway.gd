class_name HttpMatchmakingGateway
extends MatchmakingGateway

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func enter_queue(access_token: String, queue_type: String, match_format_id: String, mode_id: String, rule_set_id: String, selected_map_ids: Array[String]):
	return await _send_json_request(
		HTTPClient.METHOD_POST,
		"/api/v1/matchmaking/queue/enter",
		access_token,
		{
			"queue_type": queue_type,
			"match_format_id": match_format_id,
			"mode_id": mode_id,
			"rule_set_id": rule_set_id,
			"selected_map_ids": selected_map_ids.duplicate(),
		}
	)


func cancel_queue(access_token: String, queue_entry_id: String = ""):
	return await _send_json_request(
		HTTPClient.METHOD_POST,
		"/api/v1/matchmaking/queue/cancel",
		access_token,
		{
			"queue_entry_id": queue_entry_id,
		}
	)


func get_queue_status(access_token: String, queue_entry_id: String = ""):
	var path := "/api/v1/matchmaking/queue/status"
	if not queue_entry_id.is_empty():
		path += "?queue_entry_id=%s" % queue_entry_id.uri_encode()
	return await _send_json_request(HTTPClient.METHOD_GET, path, access_token, null)


func _send_json_request(method: int, path: String, access_token: String, payload: Variant):
	if service_base_url.is_empty():
		return _fail("MATCHMAKING_URL_MISSING", "Matchmaking service url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = method
	options.url = service_base_url + path
	options.log_tag = "front.matchmaking.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	options.body_text = "" if payload == null else JSON.stringify(payload)
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return _fail("MATCHMAKING_URL_INVALID", "Matchmaking service url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("MATCHMAKING_CONNECT_FAILED", "Failed to connect matchmaking service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("MATCHMAKING_REQUEST_FAILED", "Failed to send matchmaking request")
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return _fail("MATCHMAKING_EMPTY_RESPONSE", "Matchmaking service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("MATCHMAKING_RESPONSE_INVALID", "Matchmaking service returned invalid response")
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
