extends "res://tests/gut/base/qqt_unit_test.gd"

const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")


func test_main() -> void:
	var ok := true
	ok = _test_generate_resume_token_is_high_entropy_format() and ok
	ok = _test_hash_resume_token_is_stable() and ok


func _test_generate_resume_token_is_high_entropy_format() -> bool:
	var first := ResumeTokenUtilsScript.generate_resume_token()
	var second := ResumeTokenUtilsScript.generate_resume_token()
	var prefix := "resume_token_utils_test"
	var ok := true
	ok = qqt_check(first.length() >= 43, "token should encode at least 32 random bytes", prefix) and ok
	ok = qqt_check(not first.begins_with("token_"), "token should not use predictable legacy prefix", prefix) and ok
	ok = qqt_check(first != second, "two generated tokens should differ", prefix) and ok
	return ok


func _test_hash_resume_token_is_stable() -> bool:
	var token := "sample_resume_token"
	var first_hash := ResumeTokenUtilsScript.hash_resume_token(token)
	var second_hash := ResumeTokenUtilsScript.hash_resume_token(token)
	var prefix := "resume_token_utils_test"
	var ok := true
	ok = qqt_check(first_hash.length() == 64, "sha256 hash should be hex encoded", prefix) and ok
	ok = qqt_check(first_hash == second_hash, "same token should hash consistently", prefix) and ok
	ok = qqt_check(first_hash != token, "hash should not equal plaintext token", prefix) and ok
	return ok

