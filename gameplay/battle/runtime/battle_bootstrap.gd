class_name BattleBootstrap
extends Node

const BattleFlowStateScript = preload("res://gameplay/battle/runtime/battle_flow_state.gd")

@export var presentation_bridge_path: NodePath = ^"PresentationBridge"
@export var battle_hud_controller_path: NodePath = ^"../CanvasLayer/BattleHUD"

signal battle_flow_state_changed(previous_state: int, new_state: int, reason: String)

var battle_context: BattleContext = null
var presentation_bridge: BattlePresentationBridge = null
var battle_hud_controller: BattleHudController = null

var _rollback_corrected_connected: bool = false
var battle_flow_state: int = BattleFlowStateScript.Value.NONE


func _ready() -> void:
	set_battle_flow_state(BattleFlowStateScript.Value.LOADING_SCENE, "battle_bootstrap_ready")
	if has_node(presentation_bridge_path):
		presentation_bridge = get_node(presentation_bridge_path)
	if has_node(battle_hud_controller_path):
		battle_hud_controller = get_node(battle_hud_controller_path)
	set_battle_flow_state(BattleFlowStateScript.Value.BOOTSTRAPPING, "battle_nodes_resolved")


func bind_context(context: BattleContext) -> void:
	battle_context = context
	set_battle_flow_state(BattleFlowStateScript.Value.WAITING_START, "context_bound")
	_bind_runtime_listeners()
	set_battle_flow_state(BattleFlowStateScript.Value.RUNNING, "runtime_listeners_bound")


func release_context() -> void:
	set_battle_flow_state(BattleFlowStateScript.Value.FINISHING, "release_context_requested")
	set_process(false)
	set_physics_process(false)
	_unbind_runtime_listeners()
	battle_context = null
	set_battle_flow_state(BattleFlowStateScript.Value.FINISHED, "context_released")
	set_battle_flow_state(BattleFlowStateScript.Value.EXITING, "battle_runtime_exiting")


func debug_dump_context() -> Dictionary:
	var dump := {
		"has_context": battle_context != null,
		"has_runtime": battle_context.has_runtime() if battle_context != null else false,
		"rollback_listener_connected": _rollback_corrected_connected,
	}
	if presentation_bridge != null:
		dump["bridge"] = presentation_bridge.debug_dump_actor_summary()
	if battle_hud_controller != null:
		dump["hud"] = battle_hud_controller.debug_dump_hud_state()
	return dump


func _bind_runtime_listeners() -> void:
	if battle_context == null:
		return

	if battle_context.rollback_controller != null and not _rollback_corrected_connected:
		if not battle_context.rollback_controller.prediction_corrected.is_connected(_on_prediction_corrected):
			battle_context.rollback_controller.prediction_corrected.connect(_on_prediction_corrected)
		_rollback_corrected_connected = true


func _unbind_runtime_listeners() -> void:
	if battle_context != null and battle_context.rollback_controller != null and _rollback_corrected_connected:
		if battle_context.rollback_controller.prediction_corrected.is_connected(_on_prediction_corrected):
			battle_context.rollback_controller.prediction_corrected.disconnect(_on_prediction_corrected)
		_rollback_corrected_connected = false


func _on_prediction_corrected(_entity_id: int, _from_pos: Vector2i, _to_pos: Vector2i) -> void:
	pass


const LogBattleScript = preload("res://app/logging/log_battle.gd")

func set_battle_flow_state(new_state: int, reason: String = "") -> void:
	if battle_flow_state == new_state:
		return
	var previous_state := battle_flow_state
	battle_flow_state = new_state
	LogBattleScript.info(
		"%s -> %s (%s)" % [
			BattleFlowStateScript.state_to_string(previous_state),
			BattleFlowStateScript.state_to_string(new_state),
			reason
		],
		"",
		0,
		"battle.flow_state"
	)
	battle_flow_state_changed.emit(previous_state, new_state, reason)


func get_battle_flow_state_name() -> String:
	return BattleFlowStateScript.state_to_string(battle_flow_state)
