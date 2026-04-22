extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")


func test_practice_room_can_reach_loading_and_battle_flow() -> void:
	var runtime := qqt_add_child(AppRuntimeRootScript.new())
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	assert_true(bool(practice_result.get("ok", false)), "practice room setup succeeds")
	var entry_context = practice_result.get("entry_context", null)
	var enter_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	assert_true(bool(enter_result.get("ok", false)), "front flow can enter room from practice lobby")
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "front flow enters room state")
	runtime.debug_tools.ensure_manual_local_loop_room(runtime.room_session_controller, int(runtime.local_peer_id), int(runtime.remote_peer_id))
	if not bool(runtime.room_session_controller.room_session.ready_state.get(int(runtime.local_peer_id), false)):
		var toggle_ready_result: Dictionary = runtime.room_use_case.toggle_ready()
		assert_true(bool(toggle_ready_result.get("ok", false)), "local player can toggle ready before starting match")

	var start_result: Dictionary = runtime.room_use_case.start_match()
	assert_true(bool(start_result.get("ok", false)), "room use case can start practice match: %s" % JSON.stringify(start_result))
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING), "front flow enters loading state after match start")

	runtime.front_flow.on_loading_completed()
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "front flow enters battle state after loading completes")

	var stale_idle_snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	stale_idle_snapshot.topology = FrontTopologyScript.DEDICATED_SERVER
	stale_idle_snapshot.room_kind = FrontRoomKindScript.PRIVATE_ROOM
	stale_idle_snapshot.room_phase = "idle"
	stale_idle_snapshot.battle_phase = "active"
	runtime.room_use_case.on_authoritative_snapshot(stale_idle_snapshot)
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "idle room snapshot must not reopen room over active battle")

	var returning_snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	returning_snapshot.topology = FrontTopologyScript.DEDICATED_SERVER
	returning_snapshot.room_kind = FrontRoomKindScript.PRIVATE_ROOM
	returning_snapshot.room_phase = "returning_to_room"
	returning_snapshot.battle_phase = "returning"
	runtime.room_use_case.on_authoritative_snapshot(returning_snapshot)
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.RETURNING_TO_ROOM), "canonical returning_to_room phase should drive returning flow")

	var idle_snapshot: RoomSnapshot = returning_snapshot.duplicate_deep()
	idle_snapshot.room_phase = "idle"
	idle_snapshot.queue_phase = "idle"
	idle_snapshot.battle_phase = "completed"
	runtime.room_use_case.on_authoritative_snapshot(idle_snapshot)
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "canonical idle phase should return front flow to room")

	var battle_scene: PackedScene = load(SceneFlowControllerScript.BATTLE_SCENE_PATH)
	assert_not_null(battle_scene, "formal battle scene still loads")
