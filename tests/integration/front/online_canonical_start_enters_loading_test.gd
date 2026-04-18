extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_main() -> void:
	_main_body()


func _main_body() -> void:
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
	_assert_true(bool(enter_result.get("pending", false)), "online create stays pending before authoritative room snapshot")
	_assert_true(not runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "online create does not enter room page before authoritative room snapshot")

	runtime.room_session_controller.configure_practice_room(
		runtime.player_profile_state,
		"",
		"",
		"",
		int(runtime.local_peer_id)
	)
	var snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	snapshot.topology = FrontTopologyScript.DEDICATED_SERVER
	snapshot.room_kind = FrontRoomKindScript.PRIVATE_ROOM
	snapshot.room_id = "ROOM-CANONICAL"
	runtime.room_use_case.room_client_gateway.room_snapshot_received.emit(snapshot)
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM), "authoritative room snapshot enters room page")

	var config := BattleStartConfig.new()
	config.room_id = snapshot.room_id
	config.map_id = snapshot.selected_map_id
	config.rule_set_id = snapshot.rule_set_id
	config.mode_id = snapshot.mode_id
	config.topology = "dedicated_server"
	config.session_mode = "online_room"
	config.local_peer_id = int(runtime.local_peer_id)
	config.controlled_peer_id = int(runtime.local_peer_id)

	runtime.room_use_case.room_client_gateway.canonical_start_config_received.emit(config)
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING), "canonical start config enters loading flow")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


