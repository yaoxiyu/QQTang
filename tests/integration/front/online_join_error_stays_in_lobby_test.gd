extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_online_join_is_pending_until_snapshot_arrives()


func _test_online_join_is_pending_until_snapshot_arrives() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.front_flow.enter_lobby()

	var result: Dictionary = runtime.lobby_use_case.join_private_room("127.0.0.1", 9000, "ROOM-404")
	_assert_true(bool(result.get("ok", false)), "lobby builds online join entry context")
	var room_result: Dictionary = runtime.room_use_case.enter_room(result.get("entry_context", null))
	_assert_true(bool(room_result.get("ok", false)), "room use case accepts pending online join")
	_assert_true(bool(room_result.get("pending", false)), "online join stays pending before snapshot")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOBBY), "front flow stays in lobby before room snapshot")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
