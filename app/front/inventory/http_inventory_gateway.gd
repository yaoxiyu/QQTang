class_name HttpInventoryGateway
extends RefCounted

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_my_inventory(access_token: String) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("INVENTORY_HTTP_URL_MISSING", "Inventory HTTP url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_GET
	options.url = service_base_url + "/api/v1/inventory/me"
	options.log_tag = "front.inventory.gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	return await _execute(options)


func _execute(options) -> Dictionary:
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return _fail("INVENTORY_HTTP_URL_INVALID", "Inventory HTTP url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("INVENTORY_HTTP_CONNECT_FAILED", "Failed to connect inventory service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("INVENTORY_HTTP_REQUEST_FAILED", "Failed to send inventory request")
	if String(response.body_text).strip_edges().is_empty():
		return _fail("INVENTORY_HTTP_EMPTY_RESPONSE", "Inventory service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("INVENTORY_HTTP_RESPONSE_INVALID", "Inventory service returned invalid response")
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
