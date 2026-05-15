extends "res://tests/gut/base/qqt_unit_test.gd"

const HttpUrlParserScript = preload("res://app/infra/http/http_url_parser.gd")


func test_main() -> void:
	var ok := true
	var prefix := "http_url_parser_test"
	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "")
	OS.set_environment("QQT_REQUIRE_HTTPS", "")

	var secure_parsed := HttpUrlParserScript.parse("https://127.0.0.1:18080/api/v1/profile/me?foo=bar")
	ok = qqt_check(not secure_parsed.is_empty(), "https url should parse by default", prefix) and ok
	ok = qqt_check(bool(secure_parsed.get("use_tls", false)), "https parser should mark use_tls true", prefix) and ok

	var parsed := HttpUrlParserScript.parse("http://127.0.0.1:18080/api/v1/profile/me?foo=bar")
	ok = qqt_check(parsed.is_empty(), "http should be rejected by default", prefix) and ok

	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "1")
	parsed = HttpUrlParserScript.parse("http://127.0.0.1:18080/api/v1/profile/me?foo=bar")
	ok = qqt_check(not parsed.is_empty(), "http url with explicit port should parse", prefix) and ok
	ok = qqt_check(String(parsed.get("host", "")) == "127.0.0.1", "host should match", prefix) and ok
	ok = qqt_check(int(parsed.get("port", 0)) == 18080, "port should match", prefix) and ok
	ok = qqt_check(String(parsed.get("path", "")) == "/api/v1/profile/me?foo=bar", "path should include query", prefix) and ok
	ok = qqt_check(not bool(parsed.get("use_tls", true)), "http parser should mark use_tls false", prefix) and ok

	var root_parsed := HttpUrlParserScript.parse("http://localhost:18080")
	ok = qqt_check(String(root_parsed.get("path", "")) == "/", "path should default to slash", prefix) and ok

	var invalid_scheme := HttpUrlParserScript.parse("https://localhost:18080/api")
	ok = qqt_check(not invalid_scheme.is_empty(), "https should be accepted", prefix) and ok

	var missing_port := HttpUrlParserScript.parse("http://localhost/api")
	ok = qqt_check(int(missing_port.get("port", 0)) == 80, "http url without explicit port should default to 80", prefix) and ok

	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "")

