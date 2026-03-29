extends Node

signal flow_state_changed(state: int)
signal room_entered()
signal match_start_requested()
signal loading_started()
signal battle_started(payload)
signal settlement_opened(result: BattleResult)
signal return_to_room_requested()
signal room_returned()

enum FlowState {
	BOOT,
	ROOM,
	MATCH_LOADING,
	BATTLE,
	SETTLEMENT,
	RETURNING_TO_ROOM,
}

var current_state: FlowState = FlowState.BOOT
var scene_flow_controller: Node = null
var last_loading_payload = null


func configure(p_scene_flow_controller: Node) -> void:
	scene_flow_controller = p_scene_flow_controller


func enter_room() -> void:
	_change_state(FlowState.ROOM)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_room_scene()
	room_entered.emit()


func request_start_match() -> void:
	if current_state != FlowState.ROOM:
		return

	_change_state(FlowState.MATCH_LOADING)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_loading_scene()
	match_start_requested.emit()
	loading_started.emit()


func on_match_loading_ready(payload = null) -> void:
	if current_state != FlowState.MATCH_LOADING:
		return

	last_loading_payload = payload
	_change_state(FlowState.BATTLE)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_battle_scene()
	battle_started.emit(payload)


func on_loading_completed() -> void:
	on_match_loading_ready(null)


func on_battle_finished(result: BattleResult) -> void:
	if result == null:
		return

	_change_state(FlowState.SETTLEMENT)
	settlement_opened.emit(result)


func return_to_room() -> void:
	_change_state(FlowState.RETURNING_TO_ROOM)
	return_to_room_requested.emit()


func on_return_to_room_completed() -> void:
	_change_state(FlowState.ROOM)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_room_scene()
	room_entered.emit()
	room_returned.emit()


func is_in_state(state: FlowState) -> bool:
	return current_state == state


func get_state_name() -> StringName:
	match current_state:
		FlowState.BOOT:
			return &"BOOT"
		FlowState.ROOM:
			return &"ROOM"
		FlowState.MATCH_LOADING:
			return &"MATCH_LOADING"
		FlowState.BATTLE:
			return &"BATTLE"
		FlowState.SETTLEMENT:
			return &"SETTLEMENT"
		FlowState.RETURNING_TO_ROOM:
			return &"RETURNING_TO_ROOM"
		_:
			return &"UNKNOWN"


func _change_state(next_state: FlowState) -> void:
	if current_state == next_state:
		return

	current_state = next_state
	flow_state_changed.emit(current_state)