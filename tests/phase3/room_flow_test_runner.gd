extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_app_root_runtime_structure()
	_test_room_session_owner_transfer()
	_test_room_session_debug_dump()
	_test_match_start_config_debug_dump_is_read_only()
	_test_scene_flow_uses_formal_battle_main()
	_test_front_flow_accepts_loading_payload()
	_test_battle_scene_contract_can_instantiate()
	_test_front_flow_room_to_battle_to_return()


func _test_app_root_runtime_structure() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	_assert_true(runtime != null, "app root runtime can be created")
	_assert_true(runtime.name == "AppRoot", "app root uses formal root node name")
	_assert_true(runtime.has_node("SessionRoot"), "app root exposes SessionRoot")
	_assert_true(runtime.has_node("BattleRoot"), "app root exposes BattleRoot")
	_assert_true(runtime.has_node("DebugTools"), "app root exposes DebugTools")
	_assert_true(runtime.room_session_controller != null and runtime.room_session_controller.get_parent() == runtime.session_root, "room session controller lives under SessionRoot")
	_assert_true(runtime.match_start_coordinator != null and runtime.match_start_coordinator.get_parent() == runtime.session_root, "match start coordinator lives under SessionRoot")
	_assert_true(runtime.battle_session_adapter != null and runtime.battle_session_adapter.get_parent() == runtime.session_root, "battle session adapter lives under SessionRoot")
	_assert_true(runtime.debug_tools != null and runtime.debug_tools.get_parent() == runtime, "debug tools live under AppRoot")
	runtime.queue_free()


func _test_room_session_owner_transfer() -> void:
	var controller = RoomSessionControllerScript.new()
	add_child(controller)

	controller.create_room(11)
	controller.join_room(_make_member(22, "Beta", true))
	controller.join_room(_make_member(33, "Gamma", true))
	controller.leave_room(11)

	var snapshot := controller.build_room_snapshot()
	_assert_true(snapshot.owner_peer_id == 22, "room owner transfers to next member")
	_assert_true(snapshot.member_count() == 2, "room member count updates after owner leaves")

	controller.queue_free()


func _test_room_session_debug_dump() -> void:
	var controller = RoomSessionControllerScript.new()
	add_child(controller)

	controller.create_room(101)
	controller.join_room(_make_member(202, "Player202", true))
	controller.set_room_selection("map_alpha", "classic")

	var dump := controller.debug_dump_room()
	_assert_true(String(dump.get("room_id", "")).contains("101"), "room debug dump exposes room id")
	_assert_true(int(dump.get("owner_peer_id", 0)) == 101, "room debug dump exposes owner")
	_assert_true(String(dump.get("selected_map_id", "")) == "map_alpha", "room debug dump exposes map selection")

	controller.queue_free()


func _test_match_start_config_debug_dump_is_read_only() -> void:
	var coordinator = MatchStartCoordinatorScript.new()
	add_child(coordinator)
	coordinator.match_id_prefix = "phase3"
	coordinator.forced_seed = 777

	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "room_debug"
	snapshot.selected_map_id = "map_beta"
	snapshot.rule_set_id = "rule_beta"
	snapshot.all_ready = true
	snapshot.members = [
		_make_member(1, "A", true, 0),
		_make_member(2, "B", true, 1),
	]

	var preview_a := coordinator.debug_dump_start_config(snapshot)
	var preview_b := coordinator.debug_dump_start_config(snapshot)
	var built := coordinator.build_start_config(snapshot)

	_assert_true(String(preview_a.get("match_id", "")) == String(preview_b.get("match_id", "")), "start config debug dump is stable across repeated reads")
	_assert_true(String(built.match_id) == String(preview_a.get("match_id", "")), "debug dump does not consume match sequence")
	_assert_true(int(preview_a.get("seed", -1)) == 777, "start config debug dump exposes deterministic seed")

	coordinator.queue_free()


func _test_scene_flow_uses_formal_battle_main() -> void:
	_assert_true(SceneFlowControllerScript.BATTLE_SCENE_PATH == "res://scenes/battle/battle_main.tscn", "scene flow points to formal BattleMain path")
	_assert_true(not SceneFlowControllerScript.BATTLE_SCENE_PATH.contains("sandbox"), "scene flow no longer references sandbox battle path")


func _test_front_flow_accepts_loading_payload() -> void:
	var flow = FrontFlowControllerScript.new()
	add_child(flow)
	flow.enter_room()
	flow.request_start_match()
	var payload := {"match_id": "phase3_payload_test", "seed": 77}
	flow.on_match_loading_ready(payload)
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "front flow enters battle through formal loading ready hook")
	_assert_true(flow.last_loading_payload == payload, "front flow stores loading payload for battle handoff")
	flow.queue_free()


func _test_battle_scene_contract_can_instantiate() -> void:
	var battle_scene: PackedScene = load(SceneFlowControllerScript.BATTLE_SCENE_PATH)
	_assert_true(battle_scene != null, "formal BattleMain scene loads successfully")
	if battle_scene == null:
		return

	var battle_root := battle_scene.instantiate()
	add_child(battle_root)

	_assert_true(battle_root.has_node("BattleBootstrap"), "BattleMain exposes BattleBootstrap node")
	_assert_true(battle_root.has_node("BattleBootstrap/PresentationBridge"), "BattleMain exposes PresentationBridge node")
	_assert_true(battle_root.has_node("SpawnFxController"), "BattleMain exposes SpawnFxController node")
	_assert_true(battle_root.has_node("BattleCameraController"), "BattleMain exposes BattleCameraController node")
	_assert_true(battle_root.has_node("CanvasLayer/BattleHUD"), "BattleMain exposes BattleHUD node")
	_assert_true(battle_root.has_node("CanvasLayer/MatchMessagePanel"), "BattleMain exposes MatchMessagePanel node")
	_assert_true(battle_root.has_node("CanvasLayer/SettlementPopupAnchor/SettlementController"), "BattleMain exposes SettlementController node")

	battle_root.queue_free()


func _test_front_flow_room_to_battle_to_return() -> void:
	var flow = FrontFlowControllerScript.new()
	add_child(flow)

	flow.enter_room()
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "front flow enters room state")

	flow.request_start_match()
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING), "front flow enters loading state")

	flow.on_loading_completed()
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "front flow enters battle state")

	var result := BattleResult.new()
	result.finish_reason = "last_alive"
	result.finish_tick = 88
	flow.on_battle_finished(result)
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.SETTLEMENT), "front flow enters settlement state")

	flow.return_to_room()
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.RETURNING_TO_ROOM), "front flow enters returning state")

	flow.on_return_to_room_completed()
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "front flow returns to room state")

	flow.queue_free()


func _make_member(peer_id: int, player_name: String, ready: bool, slot_index: int = -1) -> RoomMemberState:
	var member := RoomMemberState.new()
	member.peer_id = peer_id
	member.player_name = player_name
	member.ready = ready
	member.slot_index = slot_index if slot_index >= 0 else max(peer_id % 8, 0)
	member.character_id = "hero_%d" % peer_id
	return member


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)