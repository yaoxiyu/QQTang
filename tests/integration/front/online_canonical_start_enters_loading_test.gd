extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_online_canonical_start_drives_loading_flow()


func _test_online_canonical_start_drives_loading_flow() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var entry_context := RoomEntryContextScript.new()
	entry_context.entry_kind = FrontEntryKindScript.ONLINE_CREATE
	entry_context.room_kind = FrontRoomKindScript.PRIVATE_ROOM
	entry_context.topology = FrontTopologyScript.DEDICATED_SERVER
	entry_context.return_target = FrontReturnTargetScript.LOBBY
	entry_context.server_host = "127.0.0.1"
	entry_context.server_port = 9000
	var enter_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	_assert_true(bool(enter_result.get("ok", false)), "online room entry starts successfully")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "online create enters room page before canonical start")

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	var practice_entry = practice_result.get("entry_context", null)
	runtime.room_use_case.enter_room(practice_entry)
	var snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	var config: BattleStartConfig = runtime.match_start_coordinator.build_start_config(snapshot)
	config.topology = "dedicated_server"
	config.session_mode = "online_room"
	config.local_peer_id = int(runtime.local_peer_id)
	config.controlled_peer_id = int(runtime.local_peer_id)

	runtime.room_use_case.room_client_gateway.canonical_start_config_received.emit(config)
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING), "canonical start config enters loading flow")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
