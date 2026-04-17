extends Node

const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class OneShotHttpServer:
	extends RefCounted

	var _thread := Thread.new()
	var _port: int = 0
	var _ready: bool = false
	var _response_text: String = ""

	func start(port: int, response_text: String) -> void:
		_port = port
		_response_text = response_text
		_ready = false
		_thread.start(_run)
		var deadline := Time.get_ticks_msec() + 1500
		while not _ready and Time.get_ticks_msec() < deadline:
			OS.delay_msec(10)

	func wait_done() -> void:
		if _thread.is_started():
			_thread.wait_to_finish()

	func _run() -> void:
		var server := TCPServer.new()
		var listen_err := server.listen(_port, "127.0.0.1")
		if listen_err != OK:
			_ready = true
			return
		_ready = true
		var deadline := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < deadline:
			if not server.is_connection_available():
				OS.delay_msec(5)
				continue
			var peer: StreamPeerTCP = server.take_connection()
			if peer == null:
				break
			var read_deadline := Time.get_ticks_msec() + 500
			while Time.get_ticks_msec() < read_deadline:
				peer.poll()
				if peer.get_available_bytes() > 0:
					peer.get_data(peer.get_available_bytes())
					break
				OS.delay_msec(5)
			peer.put_data(_response_text.to_utf8_buffer())
			peer.disconnect_from_host()
			break
		server.stop()


func _ready() -> void:
	var prefix := "http_request_executor_test"
	var ok := true

	ok = _test_invalid_url(prefix) and ok
	ok = _test_connect_failed(prefix) and ok
	ok = _test_200_json(prefix) and ok
	ok = _test_500_text(prefix) and ok
	ok = _test_200_invalid_json(prefix) and ok

	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)


func _test_invalid_url(prefix: String) -> bool:
	var options := HttpRequestOptionsScript.new()
	options.url = "invalid://missing"
	var response = HttpRequestExecutorScript.execute(options)
	return TestAssert.is_true(response.error_code == "HTTP_URL_INVALID", "invalid url should return HTTP_URL_INVALID", prefix)


func _test_connect_failed(prefix: String) -> bool:
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:1/ping"
	options.connect_timeout_ms = 80
	options.read_timeout_ms = 80
	var response = HttpRequestExecutorScript.execute(options)
	return TestAssert.is_true(
		response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT",
		"connect failure should be normalized",
		prefix
	)


func _test_200_json(prefix: String) -> bool:
	var server := OneShotHttpServer.new()
	var body := "{\"ok\":true,\"value\":7}"
	server.start(19181, _build_http_response("HTTP/1.1 200 OK", "application/json", body))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19181/test"
	options.parse_json = true
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	var ok := true
	ok = TestAssert.is_true(response.ok, "200 json should be ok", prefix) and ok
	ok = TestAssert.is_true(response.status_code == 200, "status code should be 200", prefix) and ok
	ok = TestAssert.is_true(response.body_json is Dictionary and bool(response.body_json.get("ok", false)), "body_json should parse dictionary", prefix) and ok
	return ok


func _test_500_text(prefix: String) -> bool:
	var server := OneShotHttpServer.new()
	var body := "server failure"
	server.start(19182, _build_http_response("HTTP/1.1 500 Internal Server Error", "text/plain", body))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19182/test"
	options.parse_json = false
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	var ok := true
	ok = TestAssert.is_true(not response.ok, "500 text should not be ok", prefix) and ok
	ok = TestAssert.is_true(response.status_code == 500, "status code should be 500", prefix) and ok
	ok = TestAssert.is_true(response.body_text == body, "body_text should preserve plain response", prefix) and ok
	return ok


func _test_200_invalid_json(prefix: String) -> bool:
	var server := OneShotHttpServer.new()
	server.start(19183, _build_http_response("HTTP/1.1 200 OK", "application/json", "{bad_json}"))
	var options := HttpRequestOptionsScript.new()
	options.url = "http://127.0.0.1:19183/test"
	options.parse_json = true
	var response = HttpRequestExecutorScript.execute(options)
	server.wait_done()
	var ok := true
	ok = TestAssert.is_true(not response.ok, "invalid json should fail", prefix) and ok
	ok = TestAssert.is_true(response.error_code == "HTTP_RESPONSE_JSON_INVALID", "invalid json should map to HTTP_RESPONSE_JSON_INVALID", prefix) and ok
	return ok


func _build_http_response(status_line: String, content_type: String, body: String) -> String:
	return "%s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		status_line,
		content_type,
		body.to_utf8_buffer().size(),
		body,
	]
