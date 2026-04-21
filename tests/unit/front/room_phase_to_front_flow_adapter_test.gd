extends "res://tests/gut/base/qqt_unit_test.gd"

const AdapterScript = preload("res://app/front/room/room_phase_to_front_flow_adapter.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")


class FakeFrontFlow:
	extends Node
	var state: int = FrontFlowControllerScript.FlowState.ROOM

	func is_in_state(target_state: int) -> bool:
		return state == target_state

	func enter_room() -> void:
		state = FrontFlowControllerScript.FlowState.ROOM

	func request_battle_entry() -> void:
		state = FrontFlowControllerScript.FlowState.MATCH_LOADING

	func request_resume_match() -> void:
		state = FrontFlowControllerScript.FlowState.MATCH_LOADING

	func on_match_loading_ready(_payload: Variant = null) -> void:
		state = FrontFlowControllerScript.FlowState.BATTLE

	func return_to_room() -> void:
		state = FrontFlowControllerScript.FlowState.RETURNING_TO_ROOM


func test_adapter_maps_battle_entry_ready_to_match_loading() -> void:
	var flow := FakeFrontFlow.new()
	flow.state = FrontFlowControllerScript.FlowState.ROOM
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_phase = "battle_entry_ready"

	AdapterScript.apply(flow, snapshot)

	assert_eq(flow.state, FrontFlowControllerScript.FlowState.MATCH_LOADING, "battle_entry_ready should drive flow into MATCH_LOADING")


func test_adapter_maps_in_battle_to_battle_scene() -> void:
	var flow := FakeFrontFlow.new()
	flow.state = FrontFlowControllerScript.FlowState.MATCH_LOADING
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_phase = "in_battle"

	AdapterScript.apply(flow, snapshot)

	assert_eq(flow.state, FrontFlowControllerScript.FlowState.BATTLE, "in_battle should drive flow into BATTLE")
