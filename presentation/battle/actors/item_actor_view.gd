class_name BattleItemActorView
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const BattleItemCatalogScript = preload("res://content/items/catalog/battle_item_catalog.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

const STAND_ANIMATION_NAME := "stand"
const STAND_ANIMATION_FPS := 8.0
const SCATTER_DURATION := 0.8
const SCATTER_HEIGHT_RATIO := 1.5
const DERIVED_ANIM_ROOT := "res://external/assets/derived/assets/animation/items"

static var _sprite_frames_cache: Dictionary = {}

var item_id: int = -1
var item_type: int = 0
var battle_item_id: String = ""
var item_color: Color = Color(1.0, 0.9, 0.2, 1.0)
var cell_size_px: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var size_px: float = BattleViewMetrics.item_half_size_px()

var _sprite: AnimatedSprite2D = null
var _fallback_body: Polygon2D = null
var _fallback_outline: Line2D = null
var _scatter_tween: Tween = null
var _scatter_target: Vector2 = Vector2.ZERO
var _scatter_state: int = 0  # 0=none, 1=flying, 2=done


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	item_id = int(view_state.get("entity_id", -1))
	item_type = int(view_state.get("item_type", 0))
	battle_item_id = String(view_state.get("battle_item_id", ""))
	cell_size_px = float(view_state.get("cell_size", cell_size_px))
	size_px = BattleViewMetrics.item_half_size_px(cell_size_px)
	var target_pos: Vector2 = view_state.get("position", Vector2.ZERO)
	item_color = view_state.get("color", item_color)
	z_as_relative = false
	if _scatter_state != 1:  # 飞行中保持 FLYING_Z，不被地面层级覆盖
		z_index = BattleDepth.item_z(view_state.get("cell", Vector2i.ZERO) as Vector2i)
	_refresh_visuals()

	var scatter_from: Vector2 = view_state.get("scatter_from", Vector2(-1, -1))
	if _scatter_state == 0 and scatter_from.x >= 0.0 and target_pos.distance_squared_to(scatter_from) > 1.0:
		_scatter_state = 1
		_start_scatter_animation(scatter_from, target_pos)
	elif _scatter_state != 1:
		position = target_pos
	# else: _scatter_state == 1 (flying), tween controls position, don't touch


func _start_scatter_animation(from: Vector2, to: Vector2) -> void:
	if _scatter_tween != null and _scatter_tween.is_valid():
		_scatter_tween.kill()
	_scatter_target = to

	position = from
	# 飞行中层级：基于飞越的最高行 + 500，确保高于该行所有表面元素
	var max_row := maxi(int(from.y / cell_size_px), int(to.y / cell_size_px))
	z_index = max_row * 100 + 500
	_fallback_body.visible = false
	_fallback_outline.visible = false

	_scatter_tween = create_tween()
	_scatter_tween.set_trans(Tween.TRANS_SINE)
	_scatter_tween.set_ease(Tween.EASE_OUT)

	var mid: Vector2 = (from + to) * 0.5
	mid.y -= cell_size_px * SCATTER_HEIGHT_RATIO

	_scatter_tween.tween_method(_on_scatter_step.bind(from, mid, to), 0.0, 1.0, SCATTER_DURATION)
	_scatter_tween.tween_callback(_on_scatter_landed)


func _on_scatter_step(t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var u: float = 1.0 - t
	position = u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _on_scatter_landed() -> void:
	position = _scatter_target
	_scatter_state = 2
	# 落地后恢复地面层级
	z_index = BattleDepth.item_z(Vector2i(int(_scatter_target.x / cell_size_px), int(_scatter_target.y / cell_size_px)))
	if _sprite.sprite_frames != null:
		_sprite.visible = true
		_fallback_body.visible = false
		_fallback_outline.visible = false
	else:
		_fallback_body.visible = true
		_fallback_outline.visible = true


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
	var stand_anim_path := _resolve_stand_anim_path()
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


func _resolve_stand_anim_path() -> String:
	if not battle_item_id.is_empty():
		if BattleItemCatalogScript.has_battle_item(battle_item_id):
			var entry: Dictionary = BattleItemCatalogScript.get_battle_item_entry(battle_item_id)
			var path: String = String(entry.get("stand_anim_path", ""))
			if not path.is_empty():
				return path
		var derived: String = "%s/%s/stand" % [DERIVED_ANIM_ROOT, battle_item_id]
		if FileAccess.file_exists(derived + "/frame_0000.png"):
			return derived

	if item_type > 0:
		var entry: Dictionary = ItemCatalogScript.get_item_entry_by_type(item_type)
		return String(entry.get("stand_anim_path", ""))

	return ""


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
