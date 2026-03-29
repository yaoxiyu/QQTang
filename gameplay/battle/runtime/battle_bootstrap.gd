class_name BattleBootstrap
extends Node

@export var presentation_bridge_path: NodePath = ^"PresentationBridge"
@export var battle_hud_controller_path: NodePath = ^"../CanvasLayer/BattleHUD"

var battle_context: BattleContext = null
var presentation_bridge: BattlePresentationBridge = null
var battle_hud_controller: BattleHudController = null

var _rollback_corrected_connected: bool = false


func _ready() -> void:
	if has_node(presentation_bridge_path):
		presentation_bridge = get_node(presentation_bridge_path)
	if has_node(battle_hud_controller_path):
		battle_hud_controller = get_node(battle_hud_controller_path)


func bind_context(context: BattleContext) -> void:
	battle_context = context
	_bind_runtime_listeners()


func release_context() -> void:
	set_process(false)
	set_physics_process(false)
	_unbind_runtime_listeners()
	battle_context = null


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
