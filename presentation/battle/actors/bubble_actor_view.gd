class_name BattleBubbleActorView
extends Node2D

var bubble_id: int = -1
var bubble_color: Color = Color(0.25, 0.35, 1.0, 1.0)
var radius: float = 12.0

var _body: Polygon2D = null
var _outline: Line2D = null


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	bubble_id = int(view_state.get("entity_id", -1))
	position = view_state.get("position", Vector2.ZERO)
	bubble_color = view_state.get("color", bubble_color)
	_refresh_visuals()


func _ensure_visuals() -> void:
	if _body == null:
		_body = Polygon2D.new()
		add_child(_body)
	if _outline == null:
		_outline = Line2D.new()
		_outline.default_color = Color(1.0, 1.0, 1.0, 0.85)
		_outline.width = 2.0
		add_child(_outline)


func _refresh_visuals() -> void:
	_ensure_visuals()
	var polygon := _build_circle_polygon(radius, 12)
	_body.polygon = polygon
	_body.color = bubble_color
	var outline_points := PackedVector2Array(polygon)
	outline_points.append(polygon[0])
	_outline.points = outline_points


func _build_circle_polygon(r: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(max(segments, 3)) - PI * 0.5
		points.append(Vector2(cos(angle), sin(angle)) * r)
	return points
