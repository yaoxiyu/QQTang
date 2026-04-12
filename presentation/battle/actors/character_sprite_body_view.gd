class_name CharacterSpriteBodyView
extends Node2D

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const DEBUG_REMOTE_ANIM_LOG := false

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
	var is_local_player := bool(view_state.get("is_local_player", false))
	var anim_is_moving := bool(view_state.get("anim_is_moving", _is_moving_state(move_state)))
	var anim_move_x := int(view_state.get("anim_move_x", 0))
	var anim_move_y := int(view_state.get("anim_move_y", 0))
	var alive := bool(view_state.get("alive", true))
	var pose_state := String(view_state.get("pose_state", "normal"))
	var animation_name := _resolve_animation_name(
		facing,
		anim_is_moving,
		anim_move_x,
		anim_move_y,
		alive,
		pose_state
	)
	if animation_name == _current_animation_name:
		if DEBUG_REMOTE_ANIM_LOG and not is_local_player:
			print(
				"[qq_remote_anim][body] entity=%d animation=%s unchanged anim_moving=%s anim_dir=(%d,%d) move_state=%d facing=%d" % [
					int(view_state.get("entity_id", -1)),
					animation_name,
					str(anim_is_moving),
					anim_move_x,
					anim_move_y,
					move_state,
					facing,
				]
			)
		return
	if animation_name.is_empty():
		if DEBUG_REMOTE_ANIM_LOG and not is_local_player:
			print(
				"[qq_remote_anim][body] entity=%d missing_animation=%s anim_moving=%s anim_dir=(%d,%d) move_state=%d facing=%d" % [
					int(view_state.get("entity_id", -1)),
					animation_name,
					str(anim_is_moving),
					anim_move_x,
					anim_move_y,
					move_state,
					facing,
				]
			)
		return

	_current_animation_name = animation_name
	_body_sprite.play(animation_name)
	if DEBUG_REMOTE_ANIM_LOG and not is_local_player:
		print(
			"[qq_remote_anim][body] entity=%d animation=%s anim_moving=%s anim_dir=(%d,%d) move_state=%d facing=%d" % [
				int(view_state.get("entity_id", -1)),
				animation_name,
				str(anim_is_moving),
				anim_move_x,
				anim_move_y,
				move_state,
				facing,
			]
		)


func _resolve_animation_name(
	facing: int,
	anim_is_moving: bool,
	anim_move_x: int,
	anim_move_y: int,
	alive: bool,
	pose_state: String
) -> String:
	var direction_suffix := _resolve_direction_suffix(facing)
	match pose_state:
		"trapped":
			direction_suffix = "down"
			return _resolve_animation_with_fallback("trapped_%s" % direction_suffix, "dead_%s" % direction_suffix)
		"victory":
			direction_suffix = "down"
			return _resolve_animation_with_fallback("victory_%s" % direction_suffix, "idle_%s" % direction_suffix)
		"defeat":
			direction_suffix = "down"
			return _resolve_animation_with_fallback("defeat_%s" % direction_suffix, "dead_%s" % direction_suffix)
		"dead":
			direction_suffix = "down"
			return _resolve_animation_with_fallback("dead_%s" % direction_suffix, "idle_%s" % direction_suffix)
		_:
			pass
	if not alive:
		direction_suffix = "down"
		return _resolve_animation_with_fallback("dead_%s" % direction_suffix, "idle_%s" % direction_suffix)
	if anim_is_moving:
		return _resolve_animation_with_fallback("run_%s" % direction_suffix, "idle_%s" % direction_suffix)
	return _resolve_animation_with_fallback("idle_%s" % direction_suffix, "")


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


func _is_moving_state(move_state: int) -> bool:
	return move_state == 1 or move_state == 3


func _resolve_animation_with_fallback(primary: String, fallback: String) -> String:
	if _body_sprite == null or _body_sprite.sprite_frames == null:
		return ""
	if not primary.is_empty() and _body_sprite.sprite_frames.has_animation(primary):
		return primary
	if not fallback.is_empty() and _body_sprite.sprite_frames.has_animation(fallback):
		return fallback
	return ""


func _resolve_sprite_pivot(animation_set: CharacterAnimationSetDef) -> Vector2:
	if animation_set == null:
		return Vector2.ZERO
	var default_origin := Vector2(float(animation_set.frame_width) * 0.5, float(animation_set.frame_height))
	var resolved_origin := animation_set.pivot_origin if animation_set.pivot_origin != Vector2.ZERO else default_origin
	if animation_set.pivot_origin == Vector2.ZERO and animation_set.pivot != Vector2.ZERO:
		resolved_origin = animation_set.pivot
	return resolved_origin + animation_set.pivot_adjust
