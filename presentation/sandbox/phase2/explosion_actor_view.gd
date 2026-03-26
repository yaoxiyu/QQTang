class_name Phase2ExplosionActorView
extends Node2D

var cell_size: float = 48.0
var covered_cells: Array[Vector2i] = []
var lifetime: float = 0.18


func configure(p_cells: Array[Vector2i], p_cell_size: float) -> void:
	covered_cells = p_cells.duplicate()
	cell_size = p_cell_size
	queue_redraw()


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	for cell in covered_cells:
		var rect := Rect2(Vector2(cell.x, cell.y) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect, Color(1.0, 0.72, 0.18, 0.55), true)
		draw_rect(rect, Color(1.0, 0.94, 0.65, 0.9), false, 2.0)
