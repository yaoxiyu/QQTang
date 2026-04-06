class_name BattleCameraController
extends Node

@export var camera_path: NodePath = ^"../Camera2D"

var _camera: Camera2D = null
var _world: SimWorld = null
var _cell_size: float = 0.0


func _ready() -> void:
	if has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func configure_from_world(world: SimWorld, cell_size: float) -> void:
	_world = world
	_cell_size = cell_size
	_refresh_camera()
	call_deferred("_refresh_camera")


func _on_viewport_size_changed() -> void:
	_refresh_camera()


func _refresh_camera() -> void:
	if _world == null or _world.state == null or _world.state.grid == null:
		return
	if _camera == null and has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D
	if _camera == null:
		return

	var grid := _world.state.grid
	var world_size: Vector2 = Vector2(float(grid.width) * _cell_size, float(grid.height) * _cell_size)
	_camera.position = world_size * 0.5

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_camera.zoom = Vector2.ONE
		return

	var zoom_x: float = world_size.x / max(viewport_size.x * 0.80, 1.0)
	var zoom_y: float = world_size.y / max(viewport_size.y * 0.80, 1.0)
	var zoom_value: float = max(max(zoom_x, zoom_y), 1.0)
	_camera.zoom = Vector2(zoom_value, zoom_value)
