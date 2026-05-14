class_name HttpShopGateway
extends RefCounted

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func fetch_catalog(access_token: String, if_none_match: int = 0) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("SHOP_HTTP_URL_MISSING", "Shop HTTP url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_GET
	var suffix := ""
	if if_none_match > 0:
		suffix = "?if_none_match=%d" % if_none_match
	options.url = service_base_url + "/api/v1/shop/catalog" + suffix
	options.log_tag = "front.shop.gateway"
	options.headers = _auth_headers(access_token)
	return await _execute(options, "SHOP")


func purchase_offer(access_token: String, offer_id: String, idempotency_key: String, expected_catalog_revision: int) -> Dictionary:
	if service_base_url.is_empty():
		return _fail("SHOP_HTTP_URL_MISSING", "Shop HTTP url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_POST
	options.url = service_base_url + "/api/v1/shop/purchases"
	options.log_tag = "front.shop.purchase.gateway"
	options.headers = _auth_headers(access_token)
	options.body_text = JSON.stringify({
		"offer_id": offer_id,
		"idempotency_key": idempotency_key,
		"expected_catalog_revision": expected_catalog_revision,
	})
	return await _execute(options, "PURCHASE")


func _auth_headers(access_token: String) -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])


func _execute(options, prefix: String) -> Dictionary:
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return _fail("%s_HTTP_URL_INVALID" % prefix, "Shop HTTP url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return _fail("%s_HTTP_CONNECT_FAILED" % prefix, "Failed to connect shop service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return _fail("%s_HTTP_REQUEST_FAILED" % prefix, "Failed to send shop request")
	if String(response.body_text).strip_edges().is_empty():
		return _fail("%s_HTTP_EMPTY_RESPONSE" % prefix, "Shop service returned empty response")
	if not (response.body_json is Dictionary):
		return _fail("%s_HTTP_RESPONSE_INVALID" % prefix, "Shop service returned invalid response")
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
