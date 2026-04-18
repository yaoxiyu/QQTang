extends "res://tests/gut/base/qqt_unit_test.gd"

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")
const OneShotHttpServerScript = preload("res://tests/helpers/http/one_shot_http_server.gd")


func test_invalid_url_returns_normalized_error() -> void:
	var options := HttpRequestOptionsScript.new()
	options.url = "invalid://missing"
	var response = HttpRequestExecutorScript.execute(options)
	assert_eq(response.error_code, "HTTP_URL_INVALID", "invalid url should return HTTP_URL_INVALID")


func test_connect_failure_is_normalized() -> void:
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:1/ping"
	options.connect_timeout_ms = 80
	options.read_timeout_ms = 80
	var response = HttpRequestExecutorScript.execute(options)
	assert_true(
		response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT",
		"connect failure should be normalized"
	)


func test_200_json_response_parses_dictionary() -> void:
	var server = OneShotHttpServerScript.new()
	var body := "{\"ok\":true,\"value\":7}"
	server.start(19181, _build_http_response("HTTP/1.1 200 OK", "application/json", body))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19181/test"
	options.parse_json = true
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	assert_true(response.ok, "200 json should be ok")
	assert_eq(response.status_code, 200, "status code should be 200")
	assert_true(response.body_json is Dictionary and bool(response.body_json.get("ok", false)), "body_json should parse dictionary")


func test_500_text_response_preserves_plain_body() -> void:
	var server = OneShotHttpServerScript.new()
	var body := "server failure"
	server.start(19182, _build_http_response("HTTP/1.1 500 Internal Server Error", "text/plain", body))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19182/test"
	options.parse_json = false
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	assert_false(response.ok, "500 text should not be ok")
	assert_eq(response.status_code, 500, "status code should be 500")
	assert_eq(response.body_text, body, "body_text should preserve plain response")


func test_invalid_json_response_maps_error_code() -> void:
	var server = OneShotHttpServerScript.new()
	server.start(19183, _build_http_response("HTTP/1.1 200 OK", "application/json", "{bad_json}"))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19183/test"
	options.parse_json = true
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	assert_false(response.ok, "invalid json should fail")
	assert_eq(response.error_code, "HTTP_RESPONSE_JSON_INVALID", "invalid json should map to HTTP_RESPONSE_JSON_INVALID")


func _build_http_response(status_line: String, content_type: String, body: String) -> String:
	return "%s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		status_line,
		content_type,
		body.to_utf8_buffer().size(),
		body,
	]

