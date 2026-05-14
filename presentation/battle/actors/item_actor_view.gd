class_name BattleItemActorView
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const BattleItemCatalogScript = preload("res://content/items/catalog/battle_item_catalog.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

const STAND_ANIMATION_NAME := "stand"
const STAND_ANIMATION_FPS := 8.0
const SCATTER_HEIGHT_RATIO := 1.5
const TICK_SECONDS := 1.0 / 30.0
const MIN_SCATTER_DURATION_SEC := 0.05
const FALLBACK_SCATTER_SPEED_PX_PER_SEC := 240.0
const SCATTER_PATH_SAMPLES := 24
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
var _scatter_target_cell: Vector2i = Vector2i.ZERO
var _scatter_state: int = 0  # 0=none, 1=flying, 2=done
var _scatter_path_points: Array[Vector2] = []
var _scatter_path_lengths: Array[float] = []
var _scatter_path_total_length: float = 0.0


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
	var target_cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	item_color = view_state.get("color", item_color)
	z_as_relative = false
	if _scatter_state != 1:  # 飞行中保持 FLYING_Z，不被地面层级覆盖
		z_index = BattleDepth.item_ground_z(target_cell)
	_refresh_visuals()

	var scatter_from: Vector2 = view_state.get("scatter_from", Vector2(-1, -1))
	var spawn_tick := int(view_state.get("spawn_tick", -1))
	var current_tick := int(view_state.get("current_tick", spawn_tick))
	var pickup_delay_ticks := int(view_state.get("pickup_delay_ticks", 0))
	var scatter_arrival_tick := spawn_tick + pickup_delay_ticks
	var scatter_arrived_by_tick := spawn_tick >= 0 and pickup_delay_ticks > 0 and current_tick >= scatter_arrival_tick
	var scatter_duration_sec := _resolve_scatter_duration_sec(scatter_from, target_pos, pickup_delay_ticks)
	if _scatter_state == 1:
		if scatter_arrived_by_tick or position.distance_squared_to(target_pos) <= 1.0:
			_finish_scatter_now(target_pos, target_cell)
			return
	var should_scatter := _scatter_state == 0 \
		and scatter_from.x >= 0.0 \
		and target_pos.distance_squared_to(scatter_from) > 1.0 \
		and not scatter_arrived_by_tick
	if should_scatter:
		_scatter_state = 1
		_start_scatter_animation(scatter_from, target_pos, target_cell, scatter_duration_sec)
	elif _scatter_state != 1:
		position = target_pos
	# else: _scatter_state == 1 (flying), tween controls position, don't touch


func _start_scatter_animation(from: Vector2, to: Vector2, target_cell: Vector2i, duration_sec: float) -> void:
	if _scatter_tween != null and _scatter_tween.is_valid():
		_scatter_tween.kill()
	_scatter_target = to
	_scatter_target_cell = target_cell

	position = from
	# 飞行中层级统一走 BattleDepth 空中深度带
	z_index = BattleDepth.item_airborne_z_from_world(from, to, cell_size_px)
	var has_sprite_frames := _sprite != null and _sprite.sprite_frames != null
	_sprite.visible = has_sprite_frames
	_fallback_body.visible = not has_sprite_frames
	_fallback_outline.visible = not has_sprite_frames

	_scatter_tween = create_tween()
	_scatter_tween.set_trans(Tween.TRANS_SINE)
	_scatter_tween.set_ease(Tween.EASE_OUT)

	var mid: Vector2 = (from + to) * 0.5
	mid.y -= cell_size_px * SCATTER_HEIGHT_RATIO
	_build_scatter_path(from, mid, to)

	_scatter_tween.tween_method(_on_scatter_step, 0.0, 1.0, maxf(duration_sec, MIN_SCATTER_DURATION_SEC))
	_scatter_tween.tween_callback(_on_scatter_landed)


func _on_scatter_step(progress: float) -> void:
	if _scatter_path_points.size() <= 1 or _scatter_path_lengths.size() <= 1 or _scatter_path_total_length <= 0.0:
		return
	var target_length := clampf(progress, 0.0, 1.0) * _scatter_path_total_length
	for i in range(1, _scatter_path_lengths.size()):
		var segment_end := _scatter_path_lengths[i]
		if target_length > segment_end and i < _scatter_path_lengths.size() - 1:
			continue
		var segment_start := _scatter_path_lengths[i - 1]
		var segment_len := maxf(segment_end - segment_start, 0.0001)
		var local_t := clampf((target_length - segment_start) / segment_len, 0.0, 1.0)
		position = _scatter_path_points[i - 1].lerp(_scatter_path_points[i], local_t)
		return
	position = _scatter_path_points[_scatter_path_points.size() - 1]


func _on_scatter_landed() -> void:
	_finish_scatter_now(_scatter_target, _scatter_target_cell)


func _finish_scatter_now(target_pos: Vector2, target_cell: Vector2i) -> void:
	if _scatter_tween != null and _scatter_tween.is_valid():
		_scatter_tween.kill()
	_scatter_tween = null
	_scatter_target = target_pos
	position = _scatter_target
	_scatter_state = 2
	# 落地后恢复地面层级
	z_index = BattleDepth.item_ground_z(target_cell)
	if _sprite.sprite_frames != null:
		_sprite.visible = true
		_fallback_body.visible = false
		_fallback_outline.visible = false
	else:
		_fallback_body.visible = true
		_fallback_outline.visible = true


func _resolve_scatter_duration_sec(scatter_from: Vector2, target_pos: Vector2, pickup_delay_ticks: int) -> float:
	if pickup_delay_ticks > 0:
		return float(pickup_delay_ticks) * TICK_SECONDS
	var distance_px := target_pos.distance_to(scatter_from)
	return distance_px / maxf(FALLBACK_SCATTER_SPEED_PX_PER_SEC, 1.0)


func _build_scatter_path(from: Vector2, mid: Vector2, to: Vector2) -> void:
	_scatter_path_points.clear()
	_scatter_path_lengths.clear()
	_scatter_path_points.append(from)
	_scatter_path_lengths.append(0.0)
	var total := 0.0
	var prev := from
	for i in range(1, SCATTER_PATH_SAMPLES + 1):
		var t := float(i) / float(SCATTER_PATH_SAMPLES)
		var point := _quadratic_bezier(from, mid, to, t)
		total += prev.distance_to(point)
		_scatter_path_points.append(point)
		_scatter_path_lengths.append(total)
		prev = point
	_scatter_path_total_length = total


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


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
