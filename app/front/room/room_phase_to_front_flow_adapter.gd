class_name RoomPhaseToFrontFlowAdapter
extends RefCounted

const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")


static func apply(front_flow: Node, snapshot: RoomSnapshot) -> void:
	if front_flow == null or snapshot == null:
		return
	if not front_flow.has_method("is_in_state"):
		return
	var room_phase := String(snapshot.room_phase).strip_edges()
	if room_phase.is_empty():
		return

	match room_phase:
		"idle":
			_enter_room(front_flow)
		"battle_entry_ready", "battle_entering":
			_enter_match_loading(front_flow)
		"in_battle":
			_enter_battle(front_flow)
		"returning_to_room":
			_enter_returning(front_flow)
		_:
			return


static func _enter_room(front_flow: Node) -> void:
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM):
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE):
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.SETTLEMENT):
		return
	if front_flow.has_method("enter_room"):
		front_flow.enter_room()


static func _enter_match_loading(front_flow: Node) -> void:
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM) and front_flow.has_method("request_battle_entry"):
		front_flow.request_battle_entry()
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOBBY) and front_flow.has_method("request_resume_match"):
		front_flow.request_resume_match()


static func _enter_battle(front_flow: Node) -> void:
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE):
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING) and front_flow.has_method("on_match_loading_ready"):
		front_flow.on_match_loading_ready(null)
		return
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.ROOM) and front_flow.has_method("request_battle_entry"):
		front_flow.request_battle_entry()


static func _enter_returning(front_flow: Node) -> void:
	if front_flow.is_in_state(FrontFlowControllerScript.FlowState.RETURNING_TO_ROOM):
		return
	if (front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE) or front_flow.is_in_state(FrontFlowControllerScript.FlowState.SETTLEMENT)) and front_flow.has_method("return_to_room"):
		front_flow.return_to_room()
