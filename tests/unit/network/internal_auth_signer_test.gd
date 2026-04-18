extends "res://tests/gut/base/qqt_unit_test.gd"

const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")


func test_sign_headers_contains_required_internal_auth_fields() -> void:
	var signer = InternalAuthSignerScript.new()
	signer.configure("kid_test", "secret_test")
	var headers := signer.sign_headers("POST", "/internal/v1/matches/finalize", "{\"a\":1}")
	var map := _headers_to_map(headers)
	assert_eq(String(map.get("Content-Type", "")), "application/json", "content type should be json")
	assert_eq(String(map.get("X-Internal-Key-Id", "")), "kid_test", "key id should match config")
	assert_true(String(map.get("X-Internal-Timestamp", "")).is_valid_int(), "timestamp should be unix seconds")
	assert_eq(String(map.get("X-Internal-Nonce", "")).length(), 32, "nonce should be 16 random bytes hex")
	assert_eq(String(map.get("X-Internal-Body-SHA256", "")).length(), 64, "body sha256 should be 64 hex chars")
	assert_eq(String(map.get("X-Internal-Signature", "")).length(), 64, "signature should be 64 hex chars")


func test_sign_headers_uses_empty_body_sha256_constant() -> void:
	var signer = InternalAuthSignerScript.new()
	signer.configure("kid_test", "secret_test")
	var headers := signer.sign_headers("POST", "/internal/v1/matches/finalize", "")
	var map := _headers_to_map(headers)
	assert_eq(
		String(map.get("X-Internal-Body-SHA256", "")),
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"empty body hash should match sha256 empty digest"
	)


func _headers_to_map(headers: PackedStringArray) -> Dictionary:
	var out := {}
	for line in headers:
		var text := String(line)
		var index := text.find(":")
		if index <= 0:
			continue
		var key := text.substr(0, index).strip_edges()
		var value := text.substr(index + 1).strip_edges()
		out[key] = value
	return out
