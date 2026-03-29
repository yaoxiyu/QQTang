class_name BattleCameraController
extends Node

@export var camera_path: NodePath = ^"../Camera2D"

var _camera: Camera2D = null


func _ready() -> void:
	if has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D


func configure_from_world(world: SimWorld, cell_size: float) -> void:
	if world == null or world.state == null or world.state.grid == null:
		return
	if _camera == null and has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D
	if _camera == null:
		return

	var grid := world.state.grid
	var world_size: Vector2 = Vector2(float(grid.width) * cell_size, float(grid.height) * cell_size)
	_camera.position = world_size * 0.5

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_camera.zoom = Vector2.ONE
		return

	var zoom_x: float = world_size.x / max(viewport_size.x * 0.80, 1.0)
	var zoom_y: float = world_size.y / max(viewport_size.y * 0.80, 1.0)
	var zoom_value: float = max(max(zoom_x, zoom_y), 1.0)
	_camera.zoom = Vector2(zoom_value, zoom_value)
