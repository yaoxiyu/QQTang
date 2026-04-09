extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var ok := await _test_public_room_connect_timeout_reports_error()
	if ok:
		print("public_room_connect_timeout_reports_error_test: PASS")
	test_finished.emit()


func _test_public_room_connect_timeout_reports_error() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.enter_lobby()

	var create_result: Dictionary = runtime.lobby_use_case.create_public_room("127.0.0.1", 9000, "Timeout Room")
	var entry_context = create_result.get("entry_context", null)
	var connection_config = runtime.room_use_case._build_connection_config(entry_context)
	connection_config.connect_timeout_sec = 0.5
	runtime.room_use_case._pending_online_entry_context = entry_context.duplicate_deep()
	runtime.room_use_case._pending_connection_config = connection_config
	runtime.room_use_case._await_room_before_enter = true

	var captured_error := {"code": "", "message": ""}
	if not runtime.client_room_runtime.room_error.is_connected(_capture_room_error.bind(captured_error)):
		runtime.client_room_runtime.room_error.connect(_capture_room_error.bind(captured_error), CONNECT_ONE_SHOT)

	runtime.room_use_case._schedule_pending_connection_watchdog(connection_config)
	await get_tree().create_timer(2.0).timeout

	var prefix := "public_room_connect_timeout_reports_error_test"
	var ok := true
	ok = TestAssert.is_true(String(captured_error.get("code", "")) == "ROOM_CONNECT_TIMEOUT", "watchdog should emit room connect timeout error", prefix) and ok
	ok = TestAssert.is_true(String(captured_error.get("message", "")).contains("timed out"), "watchdog should expose timeout message", prefix) and ok
	ok = TestAssert.is_true(runtime.room_use_case._await_room_before_enter == false, "watchdog should clear pending room state", prefix) and ok
	ok = TestAssert.is_true(runtime.room_use_case._pending_connection_config == null, "watchdog should clear pending connection config", prefix) and ok
	ok = TestAssert.is_true(runtime.room_use_case._pending_online_entry_context == null, "watchdog should clear pending entry context", prefix) and ok

	if is_instance_valid(runtime):
		runtime.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


func _capture_room_error(error_code: String, user_message: String, captured_error: Dictionary) -> void:
	captured_error["code"] = error_code
	captured_error["message"] = user_message
