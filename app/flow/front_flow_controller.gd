extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")

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

	last_loading_payload = null
	_change_state(FlowState.MATCH_LOADING)
	if scene_flow_controller != null:
		var result: int = scene_flow_controller.change_to_loading_scene()
		if result != OK:
			_route_flow_error(
				NetworkErrorCodesScript.MATCH_START_SCENE_LOAD_FAILED,
				"Failed to load loading scene",
				"request_start_match",
				{"result": result}
			)
			_change_state(FlowState.ROOM)
			return
	match_start_requested.emit()
	loading_started.emit()


func on_match_loading_ready(payload = null) -> void:
	if current_state != FlowState.MATCH_LOADING:
		return

	last_loading_payload = payload
	_change_state(FlowState.BATTLE)
	if scene_flow_controller != null:
		var result: int = scene_flow_controller.change_to_battle_scene()
		if result != OK:
			_route_flow_error(
				NetworkErrorCodesScript.MATCH_START_SCENE_LOAD_FAILED,
				"Failed to load battle scene",
				"on_match_loading_ready",
				{"result": result}
			)
			_change_state(FlowState.ROOM)
			return
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
	last_loading_payload = null
	_change_state(FlowState.ROOM)
	if scene_flow_controller != null:
		var result: int = scene_flow_controller.change_to_room_scene()
		if result != OK:
			_route_flow_error(
				NetworkErrorCodesScript.RETURN_ROOM_FAILED,
				"Failed to return to room scene",
				"on_return_to_room_completed",
				{"result": result}
			)
			_change_state(FlowState.RETURNING_TO_ROOM)
			return
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


func _route_flow_error(error_code: String, user_message: String, trigger_stage: String, log_payload: Dictionary = {}) -> void:
	var app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if app_runtime != null and app_runtime.error_router != null:
		app_runtime.error_router.route_error(
			app_runtime,
			error_code,
			"flow",
			trigger_stage,
			user_message,
			log_payload,
			"return_to_room",
			true
		)
