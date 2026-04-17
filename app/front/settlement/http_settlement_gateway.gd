class_name HttpSettlementGateway
extends SettlementGateway

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_match_summary(access_token: String, match_id: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("SETTLEMENT_URL_MISSING", "Settlement service url is missing")
	if match_id.strip_edges().is_empty():
		return _fail("SETTLEMENT_MATCH_ID_REQUIRED", "Match id is required")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_GET
	options.url = service_base_url + "/api/v1/settlement/matches/%s" % match_id.uri_encode()
	options.log_tag = "front.settlement.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var response = HttpRequestExecutorScript.execute(options)
	if response.error_code == "HTTP_URL_INVALID":
		return _fail("SETTLEMENT_URL_INVALID", "Settlement service url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("SETTLEMENT_CONNECT_FAILED", "Failed to connect settlement service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("SETTLEMENT_REQUEST_FAILED", "Failed to send settlement request")
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return _fail("SETTLEMENT_EMPTY_RESPONSE", "Settlement service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("SETTLEMENT_RESPONSE_INVALID", "Settlement service returned invalid response")
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
