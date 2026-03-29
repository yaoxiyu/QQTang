class_name BattleItemActorView
extends Node2D

var item_id: int = -1
var item_type: int = 0
var item_color: Color = Color(1.0, 0.9, 0.2, 1.0)
var size_px: float = 10.0

var _body: Polygon2D = null
var _outline: Line2D = null


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	item_id = int(view_state.get("entity_id", -1))
	item_type = int(view_state.get("item_type", 0))
	position = view_state.get("position", Vector2.ZERO)
	item_color = view_state.get("color", item_color)
	_refresh_visuals()


func _ensure_visuals() -> void:
	if _body == null:
		_body = Polygon2D.new()
		add_child(_body)
	if _outline == null:
		_outline = Line2D.new()
		_outline.default_color = Color.BLACK
		_outline.width = 2.0
		add_child(_outline)


func _refresh_visuals() -> void:
	_ensure_visuals()
	var points := PackedVector2Array([
		Vector2(0, -size_px),
		Vector2(size_px, 0),
		Vector2(0, size_px),
		Vector2(-size_px, 0)
	])
	_body.polygon = points
	_body.color = item_color
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	_outline.points = outline_points
