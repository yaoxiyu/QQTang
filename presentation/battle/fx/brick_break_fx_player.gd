class_name BrickBreakFxPlayer
extends Node2D

signal finished

const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

var _quad: Polygon2D = null


func _ready() -> void:
	_ensure_visuals()


func configure(
	world_position: Vector2,
	cell_size: float,
	break_color: Color = Color(0.95, 0.72, 0.42, 0.75),
	cell: Vector2i = Vector2i(-1, -1),
	z_override: int = -2147483648
) -> void:
	position = world_position
	_ensure_visuals()
	z_as_relative = false
	if z_override != -2147483648:
		z_index = z_override
	elif cell.x >= 0 and cell.y >= 0:
		z_index = BattleDepth.explosion_segment_z(cell)
	else:
		z_index = BattleDepth.debug_z()
	var half: float = max(cell_size * 0.35, 8.0)
	_quad.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	_quad.color = break_color
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.finished.connect(_on_tween_finished)


func reset_fx() -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)


func _on_tween_finished() -> void:
	finished.emit()


func _ensure_visuals() -> void:
	if _quad == null:
		_quad = Polygon2D.new()
		add_child(_quad)
