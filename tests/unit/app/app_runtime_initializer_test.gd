extends Node

const InitializerScript = preload("res://app/flow/app_runtime_initializer.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var prefix := "app_runtime_initializer_test"
	var result := InitializerScript.request_initialize(null)
	var ok := true
	ok = TestAssert.is_true(not bool(result.get("ok", true)), "initializer should reject null runtime", prefix) and ok
	ok = TestAssert.is_true(String(result.get("error_code", "")) == "RUNTIME_INIT_RUNTIME_INVALID", "initializer should return stable error code", prefix) and ok
	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)
