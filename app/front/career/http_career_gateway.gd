class_name HttpCareerGateway
extends CareerGateway

const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_my_career(access_token: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("CAREER_URL_MISSING", "Career service url is missing")
	var client := HTTPClient.new()
	var parsed_url := HttpRequestHelperScript.parse_url(service_base_url + "/api/v1/career/me")
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
	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"front",
		"front.career.gateway",
		"http_career_gateway",
		{
			"url": service_base_url + "/api/v1/career/me",
			"method": HTTPClient.METHOD_GET,
		}
	)
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


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
