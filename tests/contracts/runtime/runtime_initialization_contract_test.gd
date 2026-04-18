extends "res://tests/gut/base/qqt_contract_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

var _runtime_ready_signal_count: int = 0


func test_ensure_in_tree_reaches_ready_and_emits_once() -> void:
	_runtime_ready_signal_count = 0
	var runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	assert_not_null(runtime, "ensure_in_tree returns runtime instance")
	if runtime != null and runtime.has_signal("runtime_ready"):
		runtime.runtime_ready.connect(_on_runtime_ready_observed, CONNECT_ONE_SHOT)
	await qqt_wait_frames(2)
	assert_true(runtime != null and runtime.is_inside_tree(), "runtime enters scene tree after ensure_in_tree")
	assert_true(runtime != null and runtime.is_runtime_ready(), "ensure_in_tree eventually reaches ready")
	assert_eq(String(runtime.get_runtime_state_name()), "READY", "runtime state name reports READY after initialization")
	assert_eq(_runtime_ready_signal_count, 1, "runtime_ready emits exactly once during first initialization")

	var dump: Dictionary = runtime.debug_dump_runtime_structure() if runtime != null else {}
	assert_true(dump.has("runtime_state_name"), "runtime dump includes runtime_state_name")
	assert_eq(String(dump.get("runtime_state_name", "")), "READY", "runtime dump reports ready state name")

	if runtime != null:
		qqt_detach_and_free(runtime)
	await qqt_wait_frames(1)


func test_request_initialize_is_idempotent() -> void:
	var runtime: Node = qqt_add_child(AppRuntimeRootScript.new())
	runtime.initialize_runtime()
	var session_root_before = runtime.session_root
	var front_flow_before = runtime.front_flow
	var room_session_before = runtime.room_session_controller
	var child_count_before := runtime.get_child_count()

	runtime.request_initialize("contract_repeat_1")
	runtime.request_initialize("contract_repeat_2")

	assert_true(runtime.is_runtime_ready(), "request_initialize keeps runtime ready after repeated calls")
	assert_eq(runtime.session_root, session_root_before, "request_initialize does not recreate session_root")
	assert_eq(runtime.front_flow, front_flow_before, "request_initialize does not recreate front_flow")
	assert_eq(runtime.room_session_controller, room_session_before, "request_initialize does not recreate room session controller")
	assert_eq(runtime.get_child_count(), child_count_before, "request_initialize does not add duplicate runtime children")


func test_room_use_case_binds_client_room_runtime_after_initialization() -> void:
	var runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await qqt_wait_frames(2)

	assert_not_null(runtime.client_room_runtime, "runtime creates client_room_runtime during initialization")
	assert_not_null(runtime.room_use_case, "runtime creates room_use_case during initialization")
	assert_not_null(runtime.room_use_case.room_client_gateway, "room_use_case configures room_client_gateway")
	assert_eq(runtime.room_use_case.room_client_gateway.client_room_runtime, runtime.client_room_runtime, "room_use_case binds created client_room_runtime")

	qqt_detach_and_free(runtime)
	await qqt_wait_frames(1)


func _on_runtime_ready_observed() -> void:
	_runtime_ready_signal_count += 1

