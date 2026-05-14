class_name AirplaneActorView
extends Node2D

var cell_size_px: float = 48.0


func _ready() -> void:
	z_as_relative = false
	_create_placeholder()


func configure(p_cell_size: float) -> void:
	cell_size_px = p_cell_size


func update_position(world_x: float, row_y: int) -> void:
	position = Vector2(
		(world_x + 0.5) * cell_size_px,
		(float(row_y) + 0.5) * cell_size_px
	)
	z_index = row_y * 100 + 1000


func _create_placeholder() -> void:
	# 简易飞机形状（三角形向右），后续替换为正式美术资源
	var body := Polygon2D.new()
	var half := cell_size_px * 0.4
	body.polygon = PackedVector2Array([
		Vector2(half, 0),
		Vector2(-half * 0.7, half * 0.6),
		Vector2(-half * 0.3, 0),
		Vector2(-half * 0.7, -half * 0.6),
	])
	body.color = Color(0.3, 0.7, 1.0, 0.9)
	add_child(body)

	var label := Label.new()
	label.text = "✈"
	label.position = Vector2(-8, -8)
	add_child(label)


func dispose() -> void:
	if is_inside_tree():
		queue_free()
