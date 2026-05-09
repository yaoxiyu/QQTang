class_name BattleCameraController
extends Node

@export var camera_path: NodePath = ^"../Camera2D"
@export var map_top_left_anchor: Vector2 = Vector2(0.06, 0.10)
@export var map_top_left_offset_px: Vector2 = Vector2.ZERO
@export var map_origin_world: Vector2 = Vector2.ZERO

var _camera: Camera2D = null
var _world: SimWorld = null
var _cell_size: float = 0.0
var _grid_size_cells: Vector2i = Vector2i.ZERO
var _map_screen_target_rect: Rect2 = Rect2()
var _use_screen_target_rect: bool = false


func _ready() -> void:
	if has_node(camera_path):
		_camera = get_node(camera_path) as Camera2D
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func configure_from_world(world: SimWorld, cell_size: float) -> void:
	_world = world
	_cell_size = cell_size
	if _world != null and _world.state != null and _world.state.grid != null:
		_grid_size_cells = Vector2i(int(_world.state.grid.width), int(_world.state.grid.height))
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

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_camera.zoom = Vector2.ONE
		return

	if _use_screen_target_rect and _map_screen_target_rect.size.x > 0.0 and _map_screen_target_rect.size.y > 0.0:
		var target_zoom_x: float = world_size.x / max(_map_screen_target_rect.size.x, 1.0)
		var target_zoom_y: float = world_size.y / max(_map_screen_target_rect.size.y, 1.0)
		var target_zoom: float = max(target_zoom_x, target_zoom_y)
		_camera.zoom = Vector2(target_zoom, target_zoom)
		var target_top_left: Vector2 = _map_screen_target_rect.position
		_camera.position = map_origin_world - (target_top_left - viewport_size * 0.5) * target_zoom
		return

	var zoom_x: float = world_size.x / max(viewport_size.x * 0.80, 1.0)
	var zoom_y: float = world_size.y / max(viewport_size.y * 0.80, 1.0)
	var zoom_value: float = max(max(zoom_x, zoom_y), 1.0)
	_camera.zoom = Vector2(zoom_value, zoom_value)
	var desired_top_left_px := viewport_size * map_top_left_anchor + map_top_left_offset_px
	_camera.position = map_origin_world - (desired_top_left_px - viewport_size * 0.5) * zoom_value


func get_map_screen_rect() -> Rect2:
	if _camera == null:
		return Rect2()
	if _grid_size_cells.x <= 0 or _grid_size_cells.y <= 0:
		return Rect2()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var world_size := Vector2(float(_grid_size_cells.x) * _cell_size, float(_grid_size_cells.y) * _cell_size)
	var top_left_screen := (map_origin_world - _camera.position) / _camera.zoom + viewport_size * 0.5
	var map_screen_size := world_size / _camera.zoom
	return Rect2(top_left_screen, map_screen_size)


func set_map_screen_target_rect(target_rect: Rect2) -> void:
	_map_screen_target_rect = target_rect
	_use_screen_target_rect = target_rect.size.x > 0.0 and target_rect.size.y > 0.0
	_refresh_camera()


func clear_map_screen_target_rect() -> void:
	_map_screen_target_rect = Rect2()
	_use_screen_target_rect = false
	_refresh_camera()
