extends "res://tests/gut/base/qqt_contract_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")


func test_main() -> void:
	var ok := true
	ok = _test_runtime_initializes_context_objects() and ok


func _test_runtime_initializes_context_objects() -> bool:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.request_initialize("runtime_context_objects_contract_test")
	var prefix := "runtime_context_objects_contract_test"
	var ok := true
	ok = qqt_check(runtime.front_context != null, "front context should exist", prefix) and ok
	ok = qqt_check(runtime.battle_context != null, "battle context should exist", prefix) and ok
	ok = qqt_check(runtime.front_context.auth_session_state == runtime.auth_session_state, "front context should reference auth state", prefix) and ok
	ok = qqt_check(runtime.front_context.front_settings_state == runtime.front_settings_state, "front context should reference settings state", prefix) and ok
	ok = qqt_check(runtime.battle_context.current_battle_content_manifest.is_empty(), "battle context manifest starts empty", prefix) and ok
	runtime.queue_free()
	return ok

