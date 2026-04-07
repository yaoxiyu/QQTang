extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_practice_room_can_reach_loading_and_battle_flow()


func _test_practice_room_can_reach_loading_and_battle_flow() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	_assert_true(bool(practice_result.get("ok", false)), "practice room setup succeeds")
	var entry_context = practice_result.get("entry_context", null)
	var enter_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	_assert_true(bool(enter_result.get("ok", false)), "front flow can enter room from practice lobby")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "front flow enters room state")

	var start_result: Dictionary = runtime.room_use_case.start_match()
	_assert_true(bool(start_result.get("ok", false)), "room use case can start practice match")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING), "front flow enters loading state after match start")

	runtime.front_flow.on_loading_completed()
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "front flow enters battle state after loading completes")

	var battle_scene: PackedScene = load(SceneFlowControllerScript.BATTLE_SCENE_PATH)
	_assert_true(battle_scene != null, "formal battle scene still loads")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
