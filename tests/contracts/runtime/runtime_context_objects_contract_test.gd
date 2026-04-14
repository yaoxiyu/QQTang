extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := true
	ok = _test_runtime_initializes_context_objects() and ok
	if ok:
		print("runtime_context_objects_contract_test: PASS")


func _test_runtime_initializes_context_objects() -> bool:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.request_initialize("runtime_context_objects_contract_test")
	var prefix := "runtime_context_objects_contract_test"
	var ok := true
	ok = TestAssert.is_true(runtime.front_context != null, "front context should exist", prefix) and ok
	ok = TestAssert.is_true(runtime.battle_context != null, "battle context should exist", prefix) and ok
	ok = TestAssert.is_true(runtime.front_context.auth_session_state == runtime.auth_session_state, "front context should reference auth state", prefix) and ok
	ok = TestAssert.is_true(runtime.front_context.front_settings_state == runtime.front_settings_state, "front context should reference settings state", prefix) and ok
	ok = TestAssert.is_true(runtime.battle_context.current_battle_content_manifest.is_empty(), "battle context manifest starts empty", prefix) and ok
	runtime.queue_free()
	return ok
