class_name BattleMapViewController
extends Node2D

const TilePresentationLoaderScript = preload("res://content/tiles/runtime/tile_presentation_loader.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")

@export var ground_layer_path: NodePath = ^"GroundLayer"
@export var static_block_layer_path: NodePath = ^"StaticBlockLayer"
@export var breakable_block_layer_path: NodePath = ^"BreakableBlockLayer"
@export var occluder_layer_path: NodePath = ^"../OccluderLayer"
@export var actor_layer_path: NodePath = ^"../ActorLayer"

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS

var ground_layer: Node2D = null
var static_block_layer: Node2D = null
var breakable_block_layer: Node2D = null
var occluder_layer: Node2D = null
var actor_layer: Node2D = null

var _grid_cache: Dictionary = {}
var _runtime_layout: MapRuntimeLayout = null
var _map_theme: MapThemeDef = null
var _breakable_views_by_cell: Dictionary = {}
var _static_views_by_cell: Dictionary = {}
var _occluder_views: Array[Node] = []
var _tile_palette: Dictionary = {
	"ground": Color(0.88, 0.88, 0.82, 1.0),
	"solid": Color(0.20, 0.22, 0.28, 1.0),
	"breakable": Color(0.70, 0.50, 0.28, 1.0),
	"spawn": Color(0.24, 0.42, 0.26, 1.0),
	"grid_line": Color(0.10, 0.12, 0.18, 0.35),
	"occluder": Color(0.31, 0.48, 0.32, 1.0),
}


func _ready() -> void:
	_bind_layers()


func configure_map_presentation(layout: MapRuntimeLayout, map_theme: MapThemeDef, p_cell_size: float) -> void:
	_bind_layers()
	_runtime_layout = layout
	_map_theme = map_theme
	cell_size = p_cell_size
	if _map_theme != null:
		apply_tile_palette(_map_theme.tile_palette)
	_clear_runtime_layers()
	_rebuild_static_blocks()
	_rebuild_breakable_blocks()
	_rebuild_occluders()
	queue_redraw()


func apply_grid_cache(grid_cache: Dictionary, p_cell_size: float) -> void:
	_grid_cache = grid_cache.duplicate(true)
	cell_size = p_cell_size
	_prune_missing_breakable_views_from_grid_cache()
	queue_redraw()


func clear_map() -> void:
	_grid_cache.clear()
	_runtime_layout = null
	_map_theme = null
	_clear_runtime_layers()
	queue_redraw()


func apply_map_theme(map_theme: MapThemeDef) -> void:
	if map_theme == null:
		return
	_map_theme = map_theme
	apply_tile_palette(map_theme.tile_palette)


func apply_tile_palette(tile_palette: Dictionary) -> void:
	if tile_palette.is_empty():
		return
	_tile_palette = _tile_palette.duplicate(true)
	for key in ["ground", "solid", "breakable", "spawn", "grid_line", "occluder"]:
		if tile_palette.has(key):
			_tile_palette[key] = tile_palette[key]
	queue_redraw()


func handle_cell_destroyed(cell: Vector2i) -> void:
	if not _breakable_views_by_cell.has(cell):
		return
	var view : Node2D = _breakable_views_by_cell[cell]
	_breakable_views_by_cell.erase(cell)
	if view == null or not is_instance_valid(view):
		return
	if view.has_method("play_break_and_dispose"):
		view.play_break_and_dispose()
	else:
		view.queue_free()


func debug_dump_map_state() -> Dictionary:
	return {
		"grid_cells": _grid_cache.get("cells", []).size(),
		"cell_size": cell_size,
		"static_block_views": _static_views_by_cell.size(),
		"breakable_block_views": _breakable_views_by_cell.size(),
		"occluder_views": _occluder_views.size(),
	}


func _draw() -> void:
	if _grid_cache.is_empty():
		return

	for cell_data in _grid_cache.get("cells", []):
		var tile_type := int(cell_data.get("tile_type", TileConstants.TileType.EMPTY))
		var x := int(cell_data.get("x", 0))
		var y := int(cell_data.get("y", 0))
		var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect, _ground_color(tile_type), true)
		if tile_type == TileConstants.TileType.SPAWN:
			draw_rect(rect, _resolve_palette_color("spawn", Color(0.24, 0.42, 0.26, 1.0)), true)
		draw_rect(rect, _resolve_palette_color("grid_line", Color(0.10, 0.12, 0.18, 0.35)), false, 1.0)


func _bind_layers() -> void:
	if ground_layer == null and has_node(ground_layer_path):
		ground_layer = get_node(ground_layer_path) as Node2D
	if static_block_layer == null and has_node(static_block_layer_path):
		static_block_layer = get_node(static_block_layer_path) as Node2D
	if breakable_block_layer == null and has_node(breakable_block_layer_path):
		breakable_block_layer = get_node(breakable_block_layer_path) as Node2D
	if occluder_layer == null and has_node(occluder_layer_path):
		occluder_layer = get_node(occluder_layer_path) as Node2D
	if actor_layer == null and has_node(actor_layer_path):
		actor_layer = get_node(actor_layer_path) as Node2D


func _clear_runtime_layers() -> void:
	_clear_layer(static_block_layer)
	_clear_layer(breakable_block_layer)
	_clear_layer(occluder_layer)
	_static_views_by_cell.clear()
	_breakable_views_by_cell.clear()
	_occluder_views.clear()


func _clear_layer(layer: Node) -> void:
	if layer == null:
		return
	for child in layer.get_children():
		child.queue_free()


func _rebuild_static_blocks() -> void:
	if _runtime_layout == null or _map_theme == null or static_block_layer == null:
		return
	var presentation_id := String(_map_theme.solid_presentation_id)
	var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
	if presentation == null or presentation.tile_scene == null:
		return
	for cell in _runtime_layout.solid_cells:
		var view := presentation.tile_scene.instantiate()
		if view == null or not view is Node2D:
			continue
		var node := view as Node2D
		node.position = Vector2(cell.x, cell.y) * cell_size
		if node.has_method("configure"):
			node.configure(
				cell_size,
				_resolve_palette_color("solid", Color(0.20, 0.22, 0.28, 1.0)),
				float(presentation.height_px)
			)
		static_block_layer.add_child(node)
		_static_views_by_cell[cell] = node


func _rebuild_breakable_blocks() -> void:
	if _runtime_layout == null or _map_theme == null or breakable_block_layer == null:
		return
	var presentation_id := String(_map_theme.breakable_presentation_id)
	var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
	if presentation == null or presentation.tile_scene == null:
		return
	for cell in _runtime_layout.breakable_cells:
		var view := presentation.tile_scene.instantiate()
		if view == null or not view is Node2D:
			continue
		var node := view as Node2D
		node.position = Vector2(cell.x, cell.y) * cell_size
		if node.has_method("configure"):
			node.configure(
				cell_size,
				_resolve_palette_color("breakable", Color(0.70, 0.50, 0.28, 1.0)),
				float(presentation.height_px)
			)
		breakable_block_layer.add_child(node)
		_breakable_views_by_cell[cell] = node


func _rebuild_occluders() -> void:
	if _runtime_layout == null or occluder_layer == null:
		return
	for entry in _runtime_layout.foreground_overlay_entries:
		var presentation_id := String(entry.get("presentation_id", ""))
		var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
		if presentation == null or presentation.tile_scene == null:
			continue
		var view := presentation.tile_scene.instantiate()
		if view == null or not view is Node2D:
			continue
		var node := view as Node2D
		if node.has_method("configure"):
			node.configure(
				entry.get("cell", Vector2i.ZERO),
				cell_size,
				_resolve_palette_color("occluder", Color(0.31, 0.48, 0.32, 1.0)),
				entry.get("offset_px", Vector2.ZERO),
				actor_layer,
				float(presentation.fade_alpha)
			)
		occluder_layer.add_child(node)
		_occluder_views.append(node)


func _prune_missing_breakable_views_from_grid_cache() -> void:
	if _breakable_views_by_cell.is_empty():
		return
	var alive_breakable_cells := {}
	for cell_data in _grid_cache.get("cells", []):
		if int(cell_data.get("tile_type", TileConstants.TileType.EMPTY)) != TileConstants.TileType.BREAKABLE_BLOCK:
			continue
		var cell := Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
		alive_breakable_cells[cell] = true

	var stale_cells: Array[Vector2i] = []
	for cell_variant in _breakable_views_by_cell.keys():
		var cell := cell_variant as Vector2i
		if alive_breakable_cells.has(cell):
			continue
		stale_cells.append(cell)

	for cell in stale_cells:
		handle_cell_destroyed(cell)


func _ground_color(tile_type: int) -> Color:
	if tile_type == TileConstants.TileType.SPAWN:
		return _resolve_palette_color("ground", Color(0.88, 0.88, 0.82, 1.0))
	return _resolve_palette_color("ground", Color(0.88, 0.88, 0.82, 1.0))


func _resolve_palette_color(key: String, fallback: Color) -> Color:
	var color_value = _tile_palette.get(key, fallback)
	if color_value is Color:
		return color_value
	return fallback
