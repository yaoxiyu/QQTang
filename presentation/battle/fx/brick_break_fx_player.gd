class_name BrickBreakFxPlayer
extends Node2D

var _quad: Polygon2D = null


func _ready() -> void:
	_ensure_visuals()


func configure(world_position: Vector2, cell_size: float) -> void:
	position = world_position
	_ensure_visuals()
	var half: float = max(cell_size * 0.35, 8.0)
	_quad.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	_quad.color = Color(0.95, 0.72, 0.42, 0.75)
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.finished.connect(queue_free)


func _ensure_visuals() -> void:
	if _quad == null:
		_quad = Polygon2D.new()
		add_child(_quad)
