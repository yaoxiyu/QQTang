class_name BattleItemActorView
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

const STAND_ANIMATION_NAME := "stand"
const STAND_ANIMATION_FPS := 8.0

static var _sprite_frames_cache: Dictionary = {}

var item_id: int = -1
var item_type: int = 0
var item_color: Color = Color(1.0, 0.9, 0.2, 1.0)
var cell_size_px: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var size_px: float = BattleViewMetrics.item_half_size_px()

var _sprite: AnimatedSprite2D = null
var _fallback_body: Polygon2D = null
var _fallback_outline: Line2D = null


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	item_id = int(view_state.get("entity_id", -1))
	item_type = int(view_state.get("item_type", 0))
	cell_size_px = float(view_state.get("cell_size", cell_size_px))
	size_px = BattleViewMetrics.item_half_size_px(cell_size_px)
	position = view_state.get("position", Vector2.ZERO)
	item_color = view_state.get("color", item_color)
	z_as_relative = false
	z_index = BattleDepth.item_z(view_state.get("cell", Vector2i.ZERO) as Vector2i)
	_refresh_visuals()


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.visible = false
		add_child(_sprite)
	if _fallback_body == null:
		_fallback_body = Polygon2D.new()
		add_child(_fallback_body)
	if _fallback_outline == null:
		_fallback_outline = Line2D.new()
		_fallback_outline.default_color = Color.BLACK
		_fallback_outline.width = 2.0
		add_child(_fallback_outline)


func _refresh_visuals() -> void:
	_ensure_visuals()
	if _apply_stand_animation():
		_sprite.visible = true
		_fallback_body.visible = false
		_fallback_outline.visible = false
		return

	_sprite.visible = false
	_fallback_body.visible = true
	_fallback_outline.visible = true

	var points := PackedVector2Array([
		Vector2(0, -size_px),
		Vector2(size_px, 0),
		Vector2(0, size_px),
		Vector2(-size_px, 0)
	])
	_fallback_body.polygon = points
	_fallback_body.color = item_color
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	_fallback_outline.points = outline_points


func _apply_stand_animation() -> bool:
	var entry := ItemCatalogScript.get_item_entry_by_type(item_type)
	var stand_anim_path := String(entry.get("stand_anim_path", ""))
	if stand_anim_path.is_empty():
		return false

	var sprite_frames := _load_or_get_sprite_frames(stand_anim_path)
	if sprite_frames == null:
		return false

	_sprite.sprite_frames = sprite_frames
	if _sprite.animation != STAND_ANIMATION_NAME or not _sprite.is_playing():
		_sprite.play(STAND_ANIMATION_NAME)
		_sprite.speed_scale = 1.0
	return true


static func _load_or_get_sprite_frames(stand_anim_path: String) -> SpriteFrames:
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
