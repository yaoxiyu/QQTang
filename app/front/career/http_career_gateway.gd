class_name HttpCareerGateway
extends CareerGateway

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_my_career(access_token: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("CAREER_URL_MISSING", "Career service url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_GET
	options.url = service_base_url + "/api/v1/career/me"
	options.log_tag = "front.career.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var response = HttpRequestExecutorScript.execute(options)
	if response.error_code == "HTTP_URL_INVALID":
		return _fail("CAREER_URL_INVALID", "Career service url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("CAREER_CONNECT_FAILED", "Failed to connect career service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("CAREER_REQUEST_FAILED", "Failed to send career request")
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return _fail("CAREER_EMPTY_RESPONSE", "Career service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("CAREER_RESPONSE_INVALID", "Career service returned invalid response")
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
