class_name HttpCareerGateway
extends CareerGateway

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_my_career(access_token: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("CAREER_URL_MISSING", "Career service url is missing")
	var client := HTTPClient.new()
	var parsed_url := _parse_url(service_base_url + "/api/v1/career/me")
	if parsed_url.is_empty():
		return _fail("CAREER_URL_INVALID", "Career service url is invalid")
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return _fail("CAREER_CONNECT_FAILED", "Failed to connect career service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _fail("CAREER_CONNECT_FAILED", "Failed to connect career service")
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	err = client.request(HTTPClient.METHOD_GET, String(parsed_url["path"]), headers, "")
	if err != OK:
		return _fail("CAREER_REQUEST_FAILED", "Failed to send career request")
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var raw := client.read_response_body_chunk()
	var chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY or not raw.is_empty():
		chunks.append_array(raw)
		client.poll()
		raw = client.read_response_body_chunk()
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return _fail("CAREER_EMPTY_RESPONSE", "Career service returned empty response")
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return _fail("CAREER_RESPONSE_INVALID", "Career service returned invalid response")
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
