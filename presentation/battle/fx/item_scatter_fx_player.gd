class_name ItemScatterFxPlayer
extends Node2D

const PARABOLA_HEIGHT_RATIO := 1.2
const FLY_DURATION := 0.35
const STAND_ANIMATION_NAME := "stand"
const STAND_ANIMATION_FPS := 8.0

static var _sprite_frames_cache: Dictionary = {}

var _sprite: AnimatedSprite2D = null
var _tween: Tween = null
var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _cell_size: float = 40.0


func configure(p_start_world: Vector2, p_end_world: Vector2, p_cell_size: float, p_sprite_frames: SpriteFrames) -> void:
	_start_pos = p_start_world
	_end_pos = p_end_world
	_cell_size = p_cell_size

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = p_sprite_frames
	_sprite.centered = true
	_sprite.position = _start_pos
	if p_sprite_frames.has_animation("stand"):
		_sprite.play("stand")
	add_child(_sprite)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)

	var mid_point: Vector2 = (_start_pos + _end_pos) * 0.5
	mid_point.y -= _cell_size * PARABOLA_HEIGHT_RATIO

	_tween.tween_method(_on_tween_step.bind(_start_pos, mid_point, _end_pos), 0.0, 1.0, FLY_DURATION)
	_tween.tween_callback(queue_free)


func _on_tween_step(t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	position = _quadratic_bezier(p0, p1, p2, t)


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


static func load_scatter_sprite_frames(stand_anim_path: String) -> SpriteFrames:
	if _sprite_frames_cache.has(stand_anim_path):
		return _sprite_frames_cache[stand_anim_path] as SpriteFrames

	var dir := DirAccess.open(stand_anim_path)
	if dir == null:
		_sprite_frames_cache[stand_anim_path] = null
		return null

	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
			frame_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if frame_files.is_empty():
		_sprite_frames_cache[stand_anim_path] = null
		return null

	frame_files.sort()

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(STAND_ANIMATION_NAME)
	sprite_frames.set_animation_speed(STAND_ANIMATION_NAME, STAND_ANIMATION_FPS)
	sprite_frames.set_animation_loop(STAND_ANIMATION_NAME, true)

	for frame_file in frame_files:
		var texture := load(stand_anim_path + "/" + frame_file) as Texture2D
		if texture != null:
			sprite_frames.add_frame(STAND_ANIMATION_NAME, texture)

	if sprite_frames.get_frame_count(STAND_ANIMATION_NAME) == 0:
		_sprite_frames_cache[stand_anim_path] = null
		return null

	_sprite_frames_cache[stand_anim_path] = sprite_frames
	return sprite_frames
