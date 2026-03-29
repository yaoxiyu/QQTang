class_name BattlePlayerActorView
extends Node2D

var player_id: int = -1
var player_slot: int = 0
var alive: bool = true
var facing: int = 0
var radius: float = 18.0
var body_color: Color = Color(0.20, 0.70, 1.0, 1.0)

var _body: Polygon2D = null
var _marker: Polygon2D = null


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	player_id = int(view_state.get("entity_id", -1))
	player_slot = int(view_state.get("player_slot", 0))
	alive = bool(view_state.get("alive", true))
	facing = int(view_state.get("facing", 0))
	position = view_state.get("position", Vector2.ZERO)
	body_color = view_state.get("color", body_color)
	_refresh_visuals()


func _ensure_visuals() -> void:
	if _body == null:
		_body = Polygon2D.new()
		add_child(_body)
	if _marker == null:
		_marker = Polygon2D.new()
		add_child(_marker)


func _refresh_visuals() -> void:
	_ensure_visuals()
	var fill := body_color if alive else body_color.darkened(0.5)
	_body.polygon = _build_octagon(radius)
	_body.color = fill

	var marker_offset := Vector2.ZERO
	match facing:
		0:
			marker_offset = Vector2(0, -radius * 0.72)
		1:
			marker_offset = Vector2(0, radius * 0.72)
		2:
			marker_offset = Vector2(-radius * 0.72, 0)
		3:
			marker_offset = Vector2(radius * 0.72, 0)

	_marker.position = marker_offset
	_marker.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(4, 4),
		Vector2(-4, 4),
	])
	_marker.color = Color.WHITE if alive else Color(0.15, 0.15, 0.15, 1.0)


func _build_octagon(r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(8):
		var angle := TAU * float(i) / 8.0 - PI * 0.5
		points.append(Vector2(cos(angle), sin(angle)) * r)
	return points
