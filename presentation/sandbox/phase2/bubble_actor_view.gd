class_name Phase2BubbleActorView
extends Node2D

var bubble_id: int = -1
var bubble_color: Color = Color(0.25, 0.35, 1.0, 1.0)
var radius: float = 12.0


func apply_state(view_state: Dictionary) -> void:
	bubble_id = int(view_state.get("entity_id", -1))
	position = view_state.get("position", Vector2.ZERO)
	bubble_color = view_state.get("color", bubble_color)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, bubble_color)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.8), 2.0, false)
