extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

signal test_finished

var _runtime_ready_signal_count: int = 0


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	await _test_ensure_in_tree_reaches_ready_and_emits_once()
	await _test_request_initialize_is_idempotent()
	await _test_room_use_case_binds_client_room_runtime_after_initialization()
	test_finished.emit()


func _test_ensure_in_tree_reaches_ready_and_emits_once() -> void:
	_runtime_ready_signal_count = 0
	var runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_assert_true(runtime != null, "ensure_in_tree returns runtime instance")
	if runtime != null and runtime.has_signal("runtime_ready"):
		runtime.runtime_ready.connect(_on_runtime_ready_observed, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_true(runtime != null and runtime.is_inside_tree(), "runtime enters scene tree after ensure_in_tree")
	_assert_true(runtime != null and runtime.is_runtime_ready(), "ensure_in_tree eventually reaches ready")
	_assert_true(String(runtime.get_runtime_state_name()) == "READY", "runtime state name reports READY after initialization")
	_assert_true(_runtime_ready_signal_count == 1, "runtime_ready emits exactly once during first initialization")

	var dump: Dictionary = runtime.debug_dump_runtime_structure() if runtime != null else {}
	_assert_true(dump.has("runtime_state_name"), "runtime dump includes runtime_state_name")
	_assert_true(String(dump.get("runtime_state_name", "")) == "READY", "runtime dump reports ready state name")

	if runtime != null:
		runtime.queue_free()
	await get_tree().process_frame


func _test_request_initialize_is_idempotent() -> void:
	var runtime: Node = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	var session_root_before = runtime.session_root
	var front_flow_before = runtime.front_flow
	var room_session_before = runtime.room_session_controller
	var child_count_before := runtime.get_child_count()

	runtime.request_initialize("contract_repeat_1")
	runtime.request_initialize("contract_repeat_2")

	_assert_true(runtime.is_runtime_ready(), "request_initialize keeps runtime ready after repeated calls")
	_assert_true(runtime.session_root == session_root_before, "request_initialize does not recreate session_root")
	_assert_true(runtime.front_flow == front_flow_before, "request_initialize does not recreate front_flow")
	_assert_true(runtime.room_session_controller == room_session_before, "request_initialize does not recreate room session controller")
	_assert_true(runtime.get_child_count() == child_count_before, "request_initialize does not add duplicate runtime children")

	runtime.queue_free()
	await get_tree().process_frame


func _test_room_use_case_binds_client_room_runtime_after_initialization() -> void:
	var runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_true(runtime.client_room_runtime != null, "runtime creates client_room_runtime during initialization")
	_assert_true(runtime.room_use_case != null, "runtime creates room_use_case during initialization")
	_assert_true(runtime.room_use_case.room_client_gateway != null, "room_use_case configures room_client_gateway")
	_assert_true(runtime.room_use_case.room_client_gateway.client_room_runtime == runtime.client_room_runtime, "room_use_case binds created client_room_runtime")

	runtime.queue_free()
	await get_tree().process_frame


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)


func _on_runtime_ready_observed() -> void:
	_runtime_ready_signal_count += 1
