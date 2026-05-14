class_name HttpProfileGateway
extends ProfileGateway

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_my_profile(access_token: String) -> Dictionary:
	if service_base_url.is_empty():
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_URL_MISSING",
			"user_message": "Profile HTTP url is missing",
		}
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_GET
	options.url = service_base_url + "/api/v1/profile/me"
	options.log_tag = "front.profile.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_URL_INVALID",
			"user_message": "Profile HTTP url is invalid",
		}
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_CONNECT_FAILED",
			"user_message": "Failed to connect profile service",
		}
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_REQUEST_FAILED",
			"user_message": "Failed to send profile request",
		}
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_EMPTY_RESPONSE",
			"user_message": "Profile service returned empty response",
		}
	if not (response.body_json is Dictionary):
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_RESPONSE_INVALID",
			"user_message": "Profile service returned invalid response",
		}
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body


func patch_loadout(access_token: String, payload: Dictionary) -> Dictionary:
	if service_base_url.is_empty():
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_URL_MISSING",
			"user_message": "Profile HTTP url is missing",
		}
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_PATCH
	options.url = service_base_url + "/api/v1/profile/me/loadout"
	options.log_tag = "front.profile.loadout.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	options.body_text = JSON.stringify(payload)
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_URL_INVALID",
			"user_message": "Profile HTTP url is invalid",
		}
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_CONNECT_FAILED",
			"user_message": "Failed to connect profile service",
		}
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_REQUEST_FAILED",
			"user_message": "Failed to send profile request",
		}
	if String(response.body_text).strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_EMPTY_RESPONSE",
			"user_message": "Profile service returned empty response",
		}
	if not (response.body_json is Dictionary):
		return {
			"ok": false,
			"error_code": "PROFILE_HTTP_RESPONSE_INVALID",
			"user_message": "Profile service returned invalid response",
		}
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body
