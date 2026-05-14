class_name AirplaneActorView
extends Node2D

const BattleDepth = preload("res://presentation/battle/battle_depth.gd")
const AIRPLANE_STAND_ANIM_DIR := "res://external/assets/source/res/object/misc/anim/misc101_stand"
const AIRPLANE_STAND_ANIM_NAME := "stand"
const AIRPLANE_STAND_ANIM_FPS := 10.0
const AIRPLANE_SMOOTH_FOLLOW_PX_PER_SEC := 520.0

static var _sprite_frames_cache: Dictionary = {}

var cell_size_px: float = 48.0
var map_height: int = 0
var _sprite: AnimatedSprite2D = null
var _fallback_root: Node2D = null
var _target_position: Vector2 = Vector2.ZERO
var _has_target_position: bool = false


func _ready() -> void:
	z_as_relative = false
	scale = Vector2.ONE
	_ensure_visuals()
	_refresh_visuals()


func _process(delta: float) -> void:
	if not _has_target_position:
		return
	var max_step := AIRPLANE_SMOOTH_FOLLOW_PX_PER_SEC * maxf(delta, 0.0)
	position = position.move_toward(_target_position, max_step)


func configure(p_cell_size: float, p_map_height: int = 0) -> void:
	cell_size_px = p_cell_size
	map_height = maxi(p_map_height, 0)


func set_map_height(p_map_height: int) -> void:
	map_height = maxi(p_map_height, 0)


func update_position(world_x: float, row_y: int) -> void:
	_target_position = Vector2(
		(world_x + 0.5) * cell_size_px,
		(float(row_y) + 0.5) * cell_size_px
	)
	if not _has_target_position:
		position = _target_position
		_has_target_position = true
	z_index = BattleDepth.airplane_z(row_y, map_height)


func _create_placeholder() -> void:
	if _fallback_root != null:
		_fallback_root.queue_free()
	_fallback_root = Node2D.new()
	add_child(_fallback_root)
	# 资源缺失时的保底占位飞机形状（三角形向右）
	var body := Polygon2D.new()
	var half := cell_size_px * 0.4
	body.polygon = PackedVector2Array([
		Vector2(half, 0),
		Vector2(-half * 0.7, half * 0.6),
		Vector2(-half * 0.3, 0),
		Vector2(-half * 0.7, -half * 0.6),
	])
	body.color = Color(0.3, 0.7, 1.0, 0.9)
	_fallback_root.add_child(body)

	var label := Label.new()
	label.text = "✈"
	label.position = Vector2(-8, -8)
	_fallback_root.add_child(label)


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2.ONE
		add_child(_sprite)
	if _fallback_root == null:
		_create_placeholder()


func _refresh_visuals() -> void:
	_ensure_visuals()
	var sprite_frames := _load_or_get_sprite_frames(AIRPLANE_STAND_ANIM_DIR)
	if sprite_frames != null:
		_sprite.sprite_frames = sprite_frames
		_sprite.visible = true
		if _fallback_root != null:
			_fallback_root.visible = false
		if _sprite.animation != AIRPLANE_STAND_ANIM_NAME or not _sprite.is_playing():
			_sprite.play(AIRPLANE_STAND_ANIM_NAME)
			_sprite.speed_scale = 1.0
		return
	_sprite.visible = false
	if _fallback_root != null:
		_fallback_root.visible = true


static func _load_or_get_sprite_frames(anim_dir: String) -> SpriteFrames:
	if _sprite_frames_cache.has(anim_dir):
		return _sprite_frames_cache[anim_dir] as SpriteFrames

	var dir := DirAccess.open(anim_dir)
	if dir == null:
		_sprite_frames_cache[anim_dir] = null
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
		_sprite_frames_cache[anim_dir] = null
		return null

	frame_files.sort()

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(AIRPLANE_STAND_ANIM_NAME)
	sprite_frames.set_animation_speed(AIRPLANE_STAND_ANIM_NAME, AIRPLANE_STAND_ANIM_FPS)
	sprite_frames.set_animation_loop(AIRPLANE_STAND_ANIM_NAME, true)

	for frame_file in frame_files:
		var texture := load(anim_dir + "/" + frame_file) as Texture2D
		if texture != null:
			sprite_frames.add_frame(AIRPLANE_STAND_ANIM_NAME, texture)

	if sprite_frames.get_frame_count(AIRPLANE_STAND_ANIM_NAME) <= 0:
		_sprite_frames_cache[anim_dir] = null
		return null

	_sprite_frames_cache[anim_dir] = sprite_frames
	return sprite_frames


func dispose() -> void:
	if is_inside_tree():
		queue_free()
