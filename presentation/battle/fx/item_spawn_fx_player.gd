class_name ItemSpawnFxPlayer
extends Node2D

var _diamond: Polygon2D = null


func _ready() -> void:
	_ensure_visuals()


func configure(world_position: Vector2, cell_size: float, item_type: int) -> void:
	position = world_position
	_ensure_visuals()
	var half: float = max(cell_size * 0.18, 6.0)
	_diamond.polygon = PackedVector2Array([
		Vector2(0, -half),
		Vector2(half, 0),
		Vector2(0, half),
		Vector2(-half, 0),
	])
	_diamond.color = _resolve_item_color(item_type)
	scale = Vector2(0.3, 0.3)
	modulate = Color(1, 1, 1, 0.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	tween.finished.connect(queue_free)


func _ensure_visuals() -> void:
	if _diamond == null:
		_diamond = Polygon2D.new()
		add_child(_diamond)


func _resolve_item_color(item_type: int) -> Color:
	match item_type:
		1:
			return Color(1.0, 0.6, 0.2, 0.85)
		2:
			return Color(0.95, 0.92, 0.35, 0.85)
		3:
			return Color(0.35, 0.92, 0.45, 0.85)
		4:
			return Color(0.45, 0.75, 1.0, 0.85)
		_:
			return Color(1.0, 1.0, 1.0, 0.85)
