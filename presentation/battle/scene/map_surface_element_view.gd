class_name MapSurfaceElementView
extends Node2D

const FIT_CELL_WIDTH := "cell_width"
const FIT_CELL_SIZE := "cell_size"
const FIT_ORIGINAL := "original"
const DEFAULT_DIE_SECONDS := 0.36
const DEFAULT_EDGE_BLEED_PX := 1.0
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

var cell: Vector2i = Vector2i.ZERO
var footprint: Vector2i = Vector2i.ONE
var anchor_mode: String = "bottom_right"
var offset_px: Vector2 = Vector2.ZERO
var fit_mode: String = FIT_CELL_WIDTH
var cell_size: float = 40.0
var die_seconds: float = DEFAULT_DIE_SECONDS
var edge_bleed_px: float = DEFAULT_EDGE_BLEED_PX
var stand_fps: float = 12.0
var die_fps: float = 12.0
var trigger_fps: float = 12.0

var _sprite: Sprite2D = null
var _animated_sprite: AnimatedSprite2D = null
var _stand_texture: Texture2D = null
var _die_texture: Texture2D = null
var _trigger_texture: Texture2D = null
var _stand_frames: Array[Texture2D] = []
var _die_frames: Array[Texture2D] = []
var _trigger_frames: Array[Texture2D] = []
var _is_dying: bool = false


func configure(
	entry: Dictionary,
	p_cell_size: float,
	stand_texture: Texture2D,
	die_texture: Texture2D = null,
	trigger_texture: Texture2D = null,
	stand_frames: Array[Texture2D] = [],
	die_frames: Array[Texture2D] = [],
	trigger_frames: Array[Texture2D] = []
) -> void:
	cell = entry.get("cell", Vector2i.ZERO) as Vector2i
	footprint = entry.get("footprint", Vector2i.ONE) as Vector2i
	anchor_mode = String(entry.get("anchor_mode", "bottom_right"))
	offset_px = entry.get("offset_px", Vector2.ZERO) as Vector2
	cell_size = max(p_cell_size, 1.0)
	die_seconds = max(float(entry.get("die_duration_sec", DEFAULT_DIE_SECONDS)), 0.01)
	stand_fps = max(float(entry.get("stand_fps", 12.0)), 1.0)
	die_fps = max(float(entry.get("die_fps", 12.0)), 1.0)
	trigger_fps = max(float(entry.get("trigger_fps", 12.0)), 1.0)
	fit_mode = _resolve_fit_mode(entry)
	edge_bleed_px = max(float(entry.get("edge_bleed_px", _default_edge_bleed_for_fit_mode(fit_mode))), 0.0)
	z_as_relative = false
	z_index = BattleDepth.surface_z(cell, int(entry.get("z_bias", 0)))
	_stand_texture = stand_texture
	_die_texture = die_texture
	_trigger_texture = trigger_texture
	_stand_frames = stand_frames.duplicate()
	_die_frames = die_frames.duplicate()
	_trigger_frames = trigger_frames.duplicate()
	_ensure_sprite()
	_play_stand()


func play_die_and_dispose() -> void:
	if _is_dying:
		return
	_is_dying = true
	var die_duration: float = die_seconds
	if _die_frames.size() > 0:
		_apply_animated_frames(_die_frames, die_fps, false)
		die_duration = max(float(_die_frames.size()) / die_fps, 0.01)
	elif _die_texture != null:
		_apply_texture(_die_texture)
	var tween := create_tween()
	tween.tween_interval(die_duration)
	tween.tween_callback(queue_free)


func play_trigger_animation() -> void:
	if _is_dying:
		return
	if _trigger_frames.size() <= 0 and _trigger_texture == null:
		return
	var trigger_duration: float = max(float(_trigger_frames.size()) / trigger_fps, 0.01)
	if _trigger_frames.size() > 0:
		_apply_animated_frames(_trigger_frames, trigger_fps, false)
	elif _trigger_texture != null:
		_apply_texture(_trigger_texture)
	var tween := create_tween()
	tween.tween_interval(trigger_duration)
	tween.tween_callback(_play_stand)


func on_destroyed() -> void:
	play_die_and_dispose()


func on_triggered() -> void:
	play_trigger_animation()


func debug_dump_layout() -> Dictionary:
	var current_scale := Vector2.ONE
	var current_size := Vector2.ZERO
	if _animated_sprite != null and _animated_sprite.visible and _animated_sprite.sprite_frames != null:
		current_scale = _animated_sprite.scale
		if _animated_sprite.sprite_frames.has_animation("active") and _animated_sprite.sprite_frames.get_frame_count("active") > 0:
			var tex := _animated_sprite.sprite_frames.get_frame_texture("active", 0)
			if tex != null:
				current_size = tex.get_size()
	elif _sprite != null:
		current_scale = _sprite.scale
		if _sprite.texture != null:
			current_size = _sprite.texture.get_size()
	return {
		"cell": cell,
		"footprint": footprint,
		"fit_mode": fit_mode,
		"scale": current_scale,
		"position": position,
		"has_die_texture": _die_texture != null or _die_frames.size() > 0,
		"texture_size": current_size,
		"edge_bleed_px": edge_bleed_px,
	}


func _ensure_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.visible = false
		add_child(_sprite)
	if _animated_sprite == null:
		_animated_sprite = AnimatedSprite2D.new()
		_animated_sprite.centered = false
		_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_animated_sprite.visible = false
		add_child(_animated_sprite)


func _apply_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	_ensure_sprite()
	_animated_sprite.stop()
	_animated_sprite.visible = false
	_sprite.texture = texture
	_sprite.scale = _resolve_texture_scale(texture)
	_sprite.visible = true
	_apply_anchor(texture, _sprite.scale)


func _apply_animated_frames(frames: Array[Texture2D], fps: float, loop_enabled: bool) -> void:
	if frames.is_empty():
		return
	_ensure_sprite()
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("active")
	sprite_frames.set_animation_speed("active", fps)
	sprite_frames.set_animation_loop("active", loop_enabled)
	for frame in frames:
		if frame == null:
			continue
		sprite_frames.add_frame("active", frame)
	if sprite_frames.get_frame_count("active") <= 0:
		return
	var first_frame := sprite_frames.get_frame_texture("active", 0)
	if first_frame == null:
		return
	_sprite.visible = false
	_animated_sprite.sprite_frames = sprite_frames
	_animated_sprite.animation = "active"
	_animated_sprite.frame = 0
	_animated_sprite.scale = _resolve_texture_scale(first_frame)
	_animated_sprite.visible = true
	_apply_anchor(first_frame, _animated_sprite.scale)
	_animated_sprite.play("active")


func _play_stand() -> void:
	if _is_dying:
		return
	if _stand_frames.size() > 0:
		_apply_animated_frames(_stand_frames, stand_fps, true)
	else:
		_apply_texture(_stand_texture)


func _apply_anchor(texture: Texture2D, scale_value: Vector2) -> void:
	var texture_size := texture.get_size()
	var scaled_size := texture_size * scale_value
	var origin := Vector2.ZERO
	if anchor_mode == "bottom_left":
		origin = Vector2(float(cell.x) * cell_size, float(cell.y + 1) * cell_size - scaled_size.y)
	elif anchor_mode == "bottom_center":
		var left_cell := cell.x - int(floor(float(footprint.x - 1) / 2.0))
		var center_x := (float(left_cell) + float(footprint.x) * 0.5) * cell_size
		origin = Vector2(center_x - scaled_size.x * 0.5, float(cell.y + 1) * cell_size - scaled_size.y)
	else:
		origin = Vector2(float(cell.x + 1) * cell_size - scaled_size.x, float(cell.y + 1) * cell_size - scaled_size.y)
	position = origin + offset_px


func _resolve_texture_scale(texture: Texture2D) -> Vector2:
	return Vector2.ONE


func _resolve_fit_mode(entry: Dictionary) -> String:
	var explicit_fit := String(entry.get("fit_mode", "")).strip_edges()
	if not explicit_fit.is_empty():
		return explicit_fit
	if String(entry.get("render_role", "surface")) == "occluder":
		return FIT_ORIGINAL
	return FIT_CELL_WIDTH


func _default_edge_bleed_for_fit_mode(resolved_fit_mode: String) -> float:
	if resolved_fit_mode == FIT_ORIGINAL:
		return 0.0
	return DEFAULT_EDGE_BLEED_PX
