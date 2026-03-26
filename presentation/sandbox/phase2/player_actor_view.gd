class_name Phase2PlayerActorView
extends Node2D

var player_id: int = -1
var player_slot: int = 0
var alive: bool = true
var facing: int = 0
var radius: float = 18.0
var body_color: Color = Color(0.20, 0.70, 1.0, 1.0)


func apply_state(view_state: Dictionary) -> void:
	player_id = int(view_state.get("entity_id", -1))
	player_slot = int(view_state.get("player_slot", 0))
	alive = bool(view_state.get("alive", true))
	facing = int(view_state.get("facing", 0))
	position = view_state.get("position", Vector2.ZERO)
	body_color = view_state.get("color", body_color)
	queue_redraw()


func _draw() -> void:
	var fill := body_color
	if not alive:
		fill = fill.darkened(0.5)

	draw_circle(Vector2.ZERO, radius, fill)
	draw_circle(Vector2.ZERO, radius, Color.BLACK, 2.0, false)

	var facing_offset := Vector2.ZERO
	match facing:
		0:
			facing_offset = Vector2(0, -radius * 0.55)
		1:
			facing_offset = Vector2(0, radius * 0.55)
		2:
			facing_offset = Vector2(-radius * 0.55, 0)
		3:
			facing_offset = Vector2(radius * 0.55, 0)

	draw_circle(facing_offset, 5.0, Color.WHITE)

	if not alive:
		draw_line(Vector2(-radius, -radius), Vector2(radius, radius), Color.BLACK, 3.0)
		draw_line(Vector2(-radius, radius), Vector2(radius, -radius), Color.BLACK, 3.0)
