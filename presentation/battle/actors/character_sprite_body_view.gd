class_name CharacterSpriteBodyView
extends Node2D

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")

@onready var _body_sprite: AnimatedSprite2D = $BodySprite

var _animation_set: CharacterAnimationSetDef = null
var _current_animation_name: String = ""


func setup_from_animation_set(animation_set: CharacterAnimationSetDef) -> void:
	_animation_set = animation_set
	if _animation_set == null:
		_body_sprite.sprite_frames = null
		_current_animation_name = ""
		return

	_body_sprite.sprite_frames = _animation_set.sprite_frames
	_body_sprite.centered = false
	var resolved_pivot := _resolve_sprite_pivot(_animation_set)
	_body_sprite.position = -resolved_pivot
	scale = Vector2.ONE * BattleViewMetrics.player_body_scale(
		BattleViewMetrics.DEFAULT_CELL_PIXELS,
		float(_animation_set.frame_height)
	)
	_current_animation_name = ""


func apply_actor_state(view_state: Dictionary) -> void:
	if _animation_set == null or _body_sprite.sprite_frames == null:
		return

	var cell_size := float(view_state.get("cell_size", BattleViewMetrics.DEFAULT_CELL_PIXELS))
	scale = Vector2.ONE * BattleViewMetrics.player_body_scale(cell_size, float(_animation_set.frame_height))

	var facing := int(view_state.get("facing", 1))
	var move_state := int(view_state.get("move_state", 0))
	var has_input_state := view_state.has("input_move_x") or view_state.has("input_move_y")
	var input_move_x := int(view_state.get("input_move_x", 0))
	var input_move_y := int(view_state.get("input_move_y", 0))
	var alive := bool(view_state.get("alive", true))
	var animation_name := _resolve_animation_name(facing, move_state, has_input_state, input_move_x, input_move_y, alive)
	if animation_name == _current_animation_name:
		return
	if not _body_sprite.sprite_frames.has_animation(animation_name):
		return

	_current_animation_name = animation_name
	_body_sprite.play(animation_name)


func _resolve_animation_name(facing: int, move_state: int, has_input_state: bool, input_move_x: int, input_move_y: int, alive: bool) -> String:
	var direction_suffix := _resolve_direction_suffix_for_state(facing, has_input_state, input_move_x, input_move_y)
	if not alive:
		return "dead_%s" % direction_suffix
	if has_input_state:
		if _has_move_input(input_move_x, input_move_y):
			return "run_%s" % direction_suffix
		return "idle_%s" % direction_suffix
	if _is_moving_state(move_state):
		return "run_%s" % direction_suffix
	return "idle_%s" % direction_suffix


func _resolve_direction_suffix(facing: int) -> String:
	match facing:
		0:
			return "up"
		1:
			return "down"
		2:
			return "left"
		3:
			return "right"
		_:
			return "down"


func _resolve_direction_suffix_for_state(facing: int, has_input_state: bool, input_move_x: int, input_move_y: int) -> String:
	if has_input_state and _has_move_input(input_move_x, input_move_y):
		if input_move_y < 0:
			return "up"
		if input_move_y > 0:
			return "down"
		if input_move_x < 0:
			return "left"
		if input_move_x > 0:
			return "right"
	return _resolve_direction_suffix(facing)


func _is_moving_state(move_state: int) -> bool:
	return move_state == 1 or move_state == 3


func _has_move_input(input_move_x: int, input_move_y: int) -> bool:
	return input_move_x != 0 or input_move_y != 0


func _resolve_sprite_pivot(animation_set: CharacterAnimationSetDef) -> Vector2:
	if animation_set == null:
		return Vector2.ZERO
	var default_origin := Vector2(float(animation_set.frame_width) * 0.5, float(animation_set.frame_height))
	var resolved_origin := animation_set.pivot_origin if animation_set.pivot_origin != Vector2.ZERO else default_origin
	if animation_set.pivot_origin == Vector2.ZERO and animation_set.pivot != Vector2.ZERO:
		resolved_origin = animation_set.pivot
	return resolved_origin + animation_set.pivot_adjust
