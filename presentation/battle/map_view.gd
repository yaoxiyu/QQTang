class_name BattleMapView
extends Node2D

var cell_size: float = 48.0
var _grid_cache: Dictionary = {}


func apply_grid_cache(grid_cache: Dictionary, p_cell_size: float) -> void:
	_grid_cache = grid_cache.duplicate(true)
	cell_size = p_cell_size
	queue_redraw()


func clear_map() -> void:
	_grid_cache.clear()
	queue_redraw()


func debug_dump_map_state() -> Dictionary:
	return {
		"grid_cells": _grid_cache.get("cells", []).size(),
		"cell_size": cell_size,
	}


func _draw() -> void:
	if _grid_cache.is_empty():
		return

	for cell_data in _grid_cache.get("cells", []):
		var tile_type := int(cell_data.get("tile_type", TileConstants.TileType.EMPTY))
		var x := int(cell_data.get("x", 0))
		var y := int(cell_data.get("y", 0))
		var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect, _tile_color(tile_type), true)
		draw_rect(rect, Color(0.10, 0.12, 0.18, 0.35), false, 1.0)


func _tile_color(tile_type: int) -> Color:
	match tile_type:
		TileConstants.TileType.SOLID_WALL:
			return Color(0.20, 0.22, 0.28, 1.0)
		TileConstants.TileType.BREAKABLE_BLOCK:
			return Color(0.70, 0.50, 0.28, 1.0)
		TileConstants.TileType.SPAWN:
			return Color(0.24, 0.42, 0.26, 1.0)
		_:
			return Color(0.88, 0.88, 0.82, 1.0)
