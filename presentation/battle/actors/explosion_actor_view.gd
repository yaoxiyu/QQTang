class_name BattleExplosionActorView
extends Node2D

var cell_size: float = 48.0
var covered_cells: Array[Vector2i] = []
var lifetime: float = 0.18


func configure(p_cells: Array[Vector2i], p_cell_size: float) -> void:
	covered_cells = p_cells.duplicate()
	cell_size = p_cell_size
	_rebuild_cells()


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _rebuild_cells() -> void:
	for child in get_children():
		child.queue_free()

	for cell in covered_cells:
		var polygon := Polygon2D.new()
		polygon.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(cell_size, 0),
			Vector2(cell_size, cell_size),
			Vector2(0, cell_size),
		])
		polygon.color = Color(1.0, 0.72, 0.18, 0.55)
		polygon.position = Vector2(cell.x, cell.y) * cell_size
		add_child(polygon)

		var outline := Line2D.new()
		outline.default_color = Color(1.0, 0.94, 0.65, 0.9)
		outline.width = 2.0
		outline.points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(cell_size, 0),
			Vector2(cell_size, cell_size),
			Vector2(0, cell_size),
			Vector2(0, 0),
		])
		outline.position = Vector2(cell.x, cell.y) * cell_size
		add_child(outline)
