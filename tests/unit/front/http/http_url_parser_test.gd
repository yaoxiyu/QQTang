extends Node

const HttpUrlParserScript = preload("res://app/infra/http/http_url_parser.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := true
	var prefix := "http_url_parser_test"

	var parsed := HttpUrlParserScript.parse("http://127.0.0.1:18080/api/v1/profile/me?foo=bar")
	ok = TestAssert.is_true(not parsed.is_empty(), "http url with explicit port should parse", prefix) and ok
	ok = TestAssert.is_true(String(parsed.get("host", "")) == "127.0.0.1", "host should match", prefix) and ok
	ok = TestAssert.is_true(int(parsed.get("port", 0)) == 18080, "port should match", prefix) and ok
	ok = TestAssert.is_true(String(parsed.get("path", "")) == "/api/v1/profile/me?foo=bar", "path should include query", prefix) and ok
	ok = TestAssert.is_true(not bool(parsed.get("use_tls", true)), "http parser should mark use_tls false", prefix) and ok

	var root_parsed := HttpUrlParserScript.parse("http://localhost:18080")
	ok = TestAssert.is_true(String(root_parsed.get("path", "")) == "/", "path should default to slash", prefix) and ok

	var invalid_scheme := HttpUrlParserScript.parse("https://localhost:18080/api")
	ok = TestAssert.is_true(invalid_scheme.is_empty(), "https should be rejected to preserve existing behavior", prefix) and ok

	var missing_port := HttpUrlParserScript.parse("http://localhost/api")
	ok = TestAssert.is_true(missing_port.is_empty(), "url without explicit port should be rejected", prefix) and ok

	if ok:
		print("http_url_parser_test: PASS")
