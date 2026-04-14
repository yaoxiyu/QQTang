class_name HttpMatchmakingGateway
extends MatchmakingGateway

const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func enter_queue(access_token: String, queue_type: String, match_format_id: String, mode_id: String, selected_map_ids: Array[String]):
	return _send_json_request(
		HTTPClient.METHOD_POST,
		"/api/v1/matchmaking/queue/enter",
		access_token,
		{
			"queue_type": queue_type,
			"match_format_id": match_format_id,
			"mode_id": mode_id,
			"selected_map_ids": selected_map_ids.duplicate(),
		}
	)


func cancel_queue(access_token: String, queue_entry_id: String = ""):
	return _send_json_request(
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
	return _send_json_request(HTTPClient.METHOD_GET, path, access_token, null)


func _send_json_request(method: int, path: String, access_token: String, payload: Variant):
	if service_base_url.is_empty():
		return _fail("MATCHMAKING_URL_MISSING", "Matchmaking service url is missing")
	var client := HTTPClient.new()
	var parsed_url := _parse_url(service_base_url + path)
	if parsed_url.is_empty():
		return _fail("MATCHMAKING_URL_INVALID", "Matchmaking service url is invalid")
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return _fail("MATCHMAKING_CONNECT_FAILED", "Failed to connect matchmaking service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _fail("MATCHMAKING_CONNECT_FAILED", "Failed to connect matchmaking service")
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body := "" if payload == null else JSON.stringify(payload)
	err = client.request(method, String(parsed_url["path"]), headers, body)
	if err != OK:
		return _fail("MATCHMAKING_REQUEST_FAILED", "Failed to send matchmaking request")
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"front",
		"front.matchmaking.gateway",
		"http_matchmaking_gateway",
		{
			"url": service_base_url + path,
			"method": method,
		}
	)
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return _fail("MATCHMAKING_EMPTY_RESPONSE", "Matchmaking service returned empty response")
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return _fail("MATCHMAKING_RESPONSE_INVALID", "Matchmaking service returned invalid response")
	var response: Dictionary = json.data
	if not response.has("user_message") and response.has("message"):
		response["user_message"] = response.get("message", "")
	return response


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


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
