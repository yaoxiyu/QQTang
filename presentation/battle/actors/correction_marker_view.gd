class_name BattleCorrectionMarkerView
extends Node2D

var lifetime: float = 0.45
var _from_pos: Vector2 = Vector2.ZERO
var _to_pos: Vector2 = Vector2.ZERO

var _from_marker: Polygon2D = null
var _to_marker: Polygon2D = null
var _connector: Line2D = null


func configure(from_pos: Vector2, to_pos: Vector2) -> void:
	_from_pos = from_pos
	_to_pos = to_pos
	_rebuild_visuals()


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _rebuild_visuals() -> void:
	for child in get_children():
		child.queue_free()

	_connector = Line2D.new()
	_connector.default_color = Color(1.0, 0.2, 0.2, 0.95)
	_connector.width = 3.0
	_connector.points = PackedVector2Array([_from_pos, _to_pos])
	add_child(_connector)

	_from_marker = Polygon2D.new()
	_from_marker.color = Color(1.0, 0.85, 0.2, 0.95)
	_from_marker.polygon = _build_diamond(10.0)
	_from_marker.position = _from_pos
	add_child(_from_marker)

	_to_marker = Polygon2D.new()
	_to_marker.color = Color(0.15, 1.0, 0.45, 0.95)
	_to_marker.polygon = _build_diamond(12.0)
	_to_marker.position = _to_pos
	add_child(_to_marker)


func _build_diamond(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -radius),
		Vector2(radius, 0),
		Vector2(0, radius),
		Vector2(-radius, 0),
	])
