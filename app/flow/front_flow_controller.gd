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
signal return_to_source_room_requested()
signal return_to_lobby_requested()
signal room_returned()
signal lobby_entered()
signal login_entered()
signal boot_entered()
signal error_entered(error_code: String, user_message: String)

enum FlowState {
	BOOT,
	LOGIN,
	LOBBY,
	SHOP,
	INVENTORY,
	ROOM,
	MATCH_LOADING,
	BATTLE,
	SETTLEMENT,
	RETURNING_TO_ROOM,
	RETURNING_TO_LOBBY,
	ERROR,
}

var current_state: FlowState = FlowState.BOOT
var scene_flow_controller: Node = null
var last_loading_payload = null
var last_error_code: String = ""
var last_error_message: String = ""


func configure(p_scene_flow_controller: Node) -> void:
	scene_flow_controller = p_scene_flow_controller


func enter_boot() -> void:
	_change_state(FlowState.BOOT)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_boot_scene()
	boot_entered.emit()


func enter_login() -> void:
	_change_state(FlowState.LOGIN)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_login_scene()
	login_entered.emit()


func enter_lobby() -> void:
	_change_state(FlowState.LOBBY)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_lobby_scene()
	lobby_entered.emit()


func enter_shop() -> void:
	_change_state(FlowState.SHOP)
	if scene_flow_controller != null and scene_flow_controller.has_method("change_to_shop_scene"):
		scene_flow_controller.change_to_shop_scene()


func enter_inventory() -> void:
	_change_state(FlowState.INVENTORY)
	if scene_flow_controller != null and scene_flow_controller.has_method("change_to_inventory_scene"):
		scene_flow_controller.change_to_inventory_scene()


func enter_room() -> void:
	_change_state(FlowState.ROOM)
	if scene_flow_controller != null:
		scene_flow_controller.change_to_room_scene()
	room_entered.emit()


func enter_room_connect_loading() -> void:
	_enter_match_loading("enter_room_connect_loading")


func request_start_match() -> void:
	if current_state != FlowState.ROOM:
		return

	_enter_match_loading("request_start_match")


func request_resume_match() -> void:
	if current_state != FlowState.ROOM and current_state != FlowState.LOBBY:
		return

	_enter_match_loading("request_resume_match")


## Battle entry flow: room_service signals battle_entry_ready,
## client transitions to loading scene to acquire ticket and connect battle_ds.
func request_battle_entry() -> void:
	if current_state != FlowState.ROOM:
		return

	_enter_match_loading("request_battle_entry")


func _enter_match_loading(trigger_stage: String) -> void:
	last_loading_payload = null
	_change_state(FlowState.MATCH_LOADING)
	if scene_flow_controller != null:
		var result: int = scene_flow_controller.change_to_loading_scene()
		if result != OK:
			_route_flow_error(
				NetworkErrorCodesScript.MATCH_START_SCENE_LOAD_FAILED,
				"Failed to load loading scene",
				trigger_stage,
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


## After battle settlement, return to source room instead of lobby.
func return_to_source_room() -> void:
	_change_state(FlowState.RETURNING_TO_ROOM)
	return_to_source_room_requested.emit()


func return_to_lobby() -> void:
	_change_state(FlowState.RETURNING_TO_LOBBY)
	return_to_lobby_requested.emit()


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


## Called when return-to-source-room fails; fallback to lobby.
func on_return_to_source_room_failed() -> void:
	return_to_lobby()


func on_return_to_lobby_completed() -> void:
	last_loading_payload = null
	_change_state(FlowState.LOBBY)
	if scene_flow_controller != null:
		var result: int = scene_flow_controller.change_to_lobby_scene()
		if result != OK:
			_route_flow_error(
				NetworkErrorCodesScript.RETURN_ROOM_FAILED,
				"Failed to return to lobby scene",
				"on_return_to_lobby_completed",
				{"result": result}
			)
			_change_state(FlowState.RETURNING_TO_LOBBY)
			return
	lobby_entered.emit()


func enter_error(error_code: String, user_message: String) -> void:
	last_error_code = error_code
	last_error_message = user_message
	_change_state(FlowState.ERROR)
	error_entered.emit(error_code, user_message)


func is_in_state(state: FlowState) -> bool:
	return current_state == state


func get_state_name() -> StringName:
	match current_state:
		FlowState.BOOT:
			return &"BOOT"
		FlowState.LOGIN:
			return &"LOGIN"
		FlowState.LOBBY:
			return &"LOBBY"
		FlowState.SHOP:
			return &"SHOP"
		FlowState.INVENTORY:
			return &"INVENTORY"
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
		FlowState.RETURNING_TO_LOBBY:
			return &"RETURNING_TO_LOBBY"
		FlowState.ERROR:
			return &"ERROR"
		_:
			return &"UNKNOWN"


func _change_state(next_state: FlowState) -> void:
	if current_state == next_state:
		return

	current_state = next_state
	flow_state_changed.emit(current_state)


func _route_flow_error(error_code: String, user_message: String, trigger_stage: String, log_payload: Dictionary = {}) -> void:
	enter_error(error_code, user_message)
	var app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if app_runtime != null and app_runtime.error_router != null:
		app_runtime.error_router.route_error(
			app_runtime,
			error_code,
			"flow",
			trigger_stage,
			user_message,
			log_payload,
			"return_to_lobby",
			true
		)
