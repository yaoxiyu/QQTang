class_name PlayerStatusEffectViewController
extends Node2D

const JellyTrapEffectViewScript = preload("res://presentation/battle/fx/jelly_trap_effect_view.gd")
const VfxAnimationSetCatalogScript = preload("res://content/vfx_animation_sets/catalog/vfx_animation_set_catalog.gd")

@export var jelly_trap_vfx_id: String = "vfx_jelly_trap_default"

var _jelly_trap_view: Node2D = null
var _current_pose_state: String = "normal"


func apply_actor_state(view_state: Dictionary) -> void:
	var pose_state := String(view_state.get("pose_state", "normal"))
	if pose_state == _current_pose_state:
		return
	_current_pose_state = pose_state
	if pose_state == "trapped":
		_show_jelly_trap()
	else:
		_hide_jelly_trap()


func _show_jelly_trap() -> void:
	if _jelly_trap_view != null:
		return
	if not VfxAnimationSetCatalogScript.has_id(jelly_trap_vfx_id):
		return
	_jelly_trap_view = JellyTrapEffectViewScript.new()
	_jelly_trap_view.name = "JellyTrapEffectView"
	add_child(_jelly_trap_view)
	if _jelly_trap_view.setup(jelly_trap_vfx_id):
		_jelly_trap_view.play_enter_then_loop()
	else:
		_jelly_trap_view.queue_free()
		_jelly_trap_view = null


func _hide_jelly_trap() -> void:
	if _jelly_trap_view == null:
		return
	_jelly_trap_view.play_release()
	_jelly_trap_view = null
