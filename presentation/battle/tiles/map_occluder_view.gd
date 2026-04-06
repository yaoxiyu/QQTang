class_name MapOccluderView
extends Node2D

const DEFAULT_PRIMARY_COLOR := Color(0.31, 0.48, 0.32, 1.0)
const OCCLUDER_Z_INDEX := 40
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const OCCLUDER_TRIGGER_OFFSET := Vector2(-0.9, -0.6)
const OCCLUDER_TRIGGER_SIZE := Vector2(2.3, 2.0)

var cell: Vector2i = Vector2i.ZERO
var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var primary_color: Color = DEFAULT_PRIMARY_COLOR
var offset_px: Vector2 = Vector2.ZERO
var actor_layer: Node = null
var fade_alpha: float = 0.35

var _canopy_polygon: Polygon2D = null
var _is_player_inside: bool = false


func _ready() -> void:
	_bind_nodes()
	_rebuild_geometry()
	set_process(true)


func configure(
	p_cell: Vector2i,
	p_cell_size: float,
	p_primary_color: Color,
	p_offset_px: Vector2,
	p_actor_layer: Node,
	p_fade_alpha: float
) -> void:
	cell = p_cell
	cell_size = max(p_cell_size, 1.0)
	primary_color = p_primary_color
	offset_px = p_offset_px
	actor_layer = p_actor_layer
	fade_alpha = clamp(p_fade_alpha, 0.0, 1.0)
	position = Vector2(cell.x * cell_size, cell.y * cell_size) + offset_px
	z_as_relative = false
	z_index = OCCLUDER_Z_INDEX
	_bind_nodes()
	_rebuild_geometry()
	set_process(true)


func _process(delta: float) -> void:
	if _canopy_polygon == null:
		return
	var has_player_inside := _has_player_inside()
	if has_player_inside != _is_player_inside:
		_is_player_inside = has_player_inside
	var target_alpha := fade_alpha if _is_player_inside else 1.0
	var next_alpha := lerpf(modulate.a, target_alpha, min(delta * 10.0, 1.0))
	modulate.a = next_alpha


func _bind_nodes() -> void:
	if _canopy_polygon == null and has_node(^"CanopyPolygon"):
		_canopy_polygon = get_node(^"CanopyPolygon") as Polygon2D


func _rebuild_geometry() -> void:
	if _canopy_polygon == null:
		return
	_canopy_polygon.polygon = PackedVector2Array([
		Vector2(-cell_size * 0.18, -cell_size * 0.70),
		Vector2(cell_size * 1.18, -cell_size * 0.70),
		Vector2(cell_size * 1.28, cell_size * 0.28),
		Vector2(cell_size * 0.50, cell_size * 0.58),
		Vector2(-cell_size * 0.28, cell_size * 0.28),
	])
	_canopy_polygon.color = primary_color
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _has_player_inside() -> bool:
	if actor_layer == null:
		return false
	var occluder_rect := Rect2(
		global_position + Vector2(cell_size * OCCLUDER_TRIGGER_OFFSET.x, cell_size * OCCLUDER_TRIGGER_OFFSET.y),
		Vector2(cell_size * OCCLUDER_TRIGGER_SIZE.x, cell_size * OCCLUDER_TRIGGER_SIZE.y)
	)
	for child in actor_layer.get_children():
		if not child is BattlePlayerActorView:
			continue
		var player := child as BattlePlayerActorView
		if not player.alive:
			continue
		var player_sample_size := BattleViewMetrics.player_sample_size(cell_size)
		var player_rect := Rect2(
			player.global_position - player_sample_size * 0.5,
			player_sample_size
		)
		if occluder_rect.intersects(player_rect):
			return true
	return false
