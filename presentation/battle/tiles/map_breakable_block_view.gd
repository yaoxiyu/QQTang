class_name MapBreakableBlockView
extends Node2D

const DEFAULT_PRIMARY_COLOR := Color(0.70, 0.50, 0.28, 1.0)
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var primary_color: Color = DEFAULT_PRIMARY_COLOR
var height_px: float = 14.0

var _shadow_polygon: Polygon2D = null
var _base_polygon: Polygon2D = null
var _top_polygon: Polygon2D = null
var _is_breaking: bool = false


func _ready() -> void:
	_bind_nodes()
	_rebuild_geometry()


func configure(p_cell_size: float, p_primary_color: Color, p_height_px: float) -> void:
	cell_size = max(p_cell_size, 1.0)
	primary_color = p_primary_color
	height_px = max(p_height_px, 0.0)
	_bind_nodes()
	_rebuild_geometry()


func play_break_and_dispose() -> void:
	if _is_breaking:
		return
	_is_breaking = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.35, 0.35), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.finished.connect(queue_free)


func _bind_nodes() -> void:
	if _shadow_polygon == null and has_node(^"ShadowPolygon"):
		_shadow_polygon = get_node(^"ShadowPolygon") as Polygon2D
	if _base_polygon == null and has_node(^"BasePolygon"):
		_base_polygon = get_node(^"BasePolygon") as Polygon2D
	if _top_polygon == null and has_node(^"TopPolygon"):
		_top_polygon = get_node(^"TopPolygon") as Polygon2D


func _rebuild_geometry() -> void:
	if _shadow_polygon == null or _base_polygon == null or _top_polygon == null:
		return

	var inset := cell_size * 0.08
	var top_y := -height_px
	_base_polygon.polygon = PackedVector2Array([
		Vector2(inset, 0.0),
		Vector2(cell_size - inset, 0.0),
		Vector2(cell_size, cell_size),
		Vector2(0.0, cell_size),
	])
	_top_polygon.polygon = PackedVector2Array([
		Vector2(inset, top_y),
		Vector2(cell_size - inset, top_y),
		Vector2(cell_size - inset, 0.0),
		Vector2(inset, 0.0),
	])
	_shadow_polygon.polygon = PackedVector2Array([
		Vector2(cell_size * 0.08, cell_size),
		Vector2(cell_size * 0.92, cell_size),
		Vector2(cell_size + height_px * 0.25, cell_size + height_px * 0.16),
		Vector2(cell_size * 0.18, cell_size + height_px * 0.16),
	])

	_top_polygon.color = _lighten(primary_color, 0.12)
	_base_polygon.color = primary_color
	_shadow_polygon.color = Color(primary_color.r * 0.42, primary_color.g * 0.42, primary_color.b * 0.42, 0.42)


func _lighten(color_value: Color, amount: float) -> Color:
	return Color(
		min(color_value.r + amount, 1.0),
		min(color_value.g + amount, 1.0),
		min(color_value.b + amount, 1.0),
		color_value.a
	)
