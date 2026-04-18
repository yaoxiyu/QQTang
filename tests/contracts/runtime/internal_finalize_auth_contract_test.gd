extends "res://tests/gut/base/qqt_contract_test.gd"

const TARGET_FILE := "res://network/session/runtime/server_match_finalize_reporter.gd"
const INTERNAL_CLIENT_FILE := "res://app/infra/http/internal_json_service_client.gd"


func test_server_match_finalize_reporter_uses_internal_auth_signer_contract() -> void:
	var reporter_source := _read_text(TARGET_FILE)
	assert_false(reporter_source.is_empty(), "target source should be readable")
	assert_true(reporter_source.find("InternalJsonServiceClientScript") >= 0, "finalize reporter should use InternalJsonServiceClient")
	assert_true(reporter_source.find("GAME_INTERNAL_AUTH_KEY_ID") >= 0, "finalize reporter should read key id env")
	assert_true(reporter_source.find("GAME_INTERNAL_AUTH_SHARED_SECRET") >= 0, "finalize reporter should read auth shared secret env")
	assert_true(reporter_source.find("has_internal_auth_secret") >= 0, "finalize reporter should expose new log field name")
	assert_true(reporter_source.find("X-Internal-Secret") < 0, "legacy internal secret header should be removed")
	assert_true(reporter_source.find("has_internal_secret") < 0, "legacy log field should be removed")

	var client_source := _read_text(INTERNAL_CLIENT_FILE)
	assert_false(client_source.is_empty(), "internal json service client source should be readable")
	assert_true(client_source.find("InternalAuthSignerScript") >= 0, "internal json client should use internal auth signer")
	assert_true(client_source.find("sign_headers") >= 0, "internal json client should generate signed headers")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
