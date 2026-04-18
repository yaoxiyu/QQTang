extends "res://tests/gut/base/qqt_unit_test.gd"

const InitializerScript = preload("res://app/flow/app_runtime_initializer.gd")


func test_main() -> void:
	var prefix := "app_runtime_initializer_test"
	var result := InitializerScript.request_initialize(null)
	var ok := true
	ok = qqt_check(not bool(result.get("ok", true)), "initializer should reject null runtime", prefix) and ok
	ok = qqt_check(String(result.get("error_code", "")) == "RUNTIME_INIT_RUNTIME_INVALID", "initializer should return stable error code", prefix) and ok


