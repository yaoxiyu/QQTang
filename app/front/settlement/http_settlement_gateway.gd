class_name HttpSettlementGateway
extends SettlementGateway

const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_match_summary(access_token: String, match_id: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("SETTLEMENT_URL_MISSING", "Settlement service url is missing")
	if match_id.strip_edges().is_empty():
		return _fail("SETTLEMENT_MATCH_ID_REQUIRED", "Match id is required")
	var client := HTTPClient.new()
	var parsed_url := HttpRequestHelperScript.parse_url(service_base_url + "/api/v1/settlement/matches/%s" % match_id.uri_encode())
	if parsed_url.is_empty():
		return _fail("SETTLEMENT_URL_INVALID", "Settlement service url is invalid")
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return _fail("SETTLEMENT_CONNECT_FAILED", "Failed to connect settlement service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _fail("SETTLEMENT_CONNECT_FAILED", "Failed to connect settlement service")
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	err = client.request(HTTPClient.METHOD_GET, String(parsed_url["path"]), headers, "")
	if err != OK:
		return _fail("SETTLEMENT_REQUEST_FAILED", "Failed to send settlement request")
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"front",
		"front.settlement.gateway",
		"http_settlement_gateway",
		{
			"url": service_base_url + "/api/v1/settlement/matches/%s" % match_id.uri_encode(),
			"method": HTTPClient.METHOD_GET,
			"match_id": match_id,
		}
	)
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return _fail("SETTLEMENT_EMPTY_RESPONSE", "Settlement service returned empty response")
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return _fail("SETTLEMENT_RESPONSE_INVALID", "Settlement service returned invalid response")
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
