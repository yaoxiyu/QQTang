class_name Phase2ItemActorView
extends Node2D

var item_id: int = -1
var item_type: int = 0
var item_color: Color = Color(1.0, 0.9, 0.2, 1.0)
var size_px: float = 10.0


func apply_state(view_state: Dictionary) -> void:
	item_id = int(view_state.get("entity_id", -1))
	item_type = int(view_state.get("item_type", 0))
	position = view_state.get("position", Vector2.ZERO)
	item_color = view_state.get("color", item_color)
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -size_px),
		Vector2(size_px, 0),
		Vector2(0, size_px),
		Vector2(-size_px, 0)
	])
	draw_colored_polygon(points, item_color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 2.0)
