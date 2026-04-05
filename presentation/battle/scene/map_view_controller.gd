class_name BattleMapViewController
extends Node2D

var cell_size: float = 48.0
var _grid_cache: Dictionary = {}
var _tile_palette: Dictionary = {
	"ground": Color(0.88, 0.88, 0.82, 1.0),
	"solid": Color(0.20, 0.22, 0.28, 1.0),
	"breakable": Color(0.70, 0.50, 0.28, 1.0),
	"spawn": Color(0.24, 0.42, 0.26, 1.0),
	"grid_line": Color(0.10, 0.12, 0.18, 0.35),
}


func apply_grid_cache(grid_cache: Dictionary, p_cell_size: float) -> void:
	_grid_cache = grid_cache.duplicate(true)
	cell_size = p_cell_size
	queue_redraw()


func clear_map() -> void:
	_grid_cache.clear()
	queue_redraw()


func apply_map_theme(map_theme: MapThemeDef) -> void:
	if map_theme == null:
		return
	apply_tile_palette(map_theme.tile_palette)


func apply_tile_palette(tile_palette: Dictionary) -> void:
	if tile_palette.is_empty():
		return
	_tile_palette = _tile_palette.duplicate(true)
	for key in ["ground", "solid", "breakable", "spawn", "grid_line"]:
		if tile_palette.has(key):
			_tile_palette[key] = tile_palette[key]
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
		draw_rect(rect, _resolve_palette_color("grid_line", Color(0.10, 0.12, 0.18, 0.35)), false, 1.0)


func _tile_color(tile_type: int) -> Color:
	match tile_type:
		TileConstants.TileType.SOLID_WALL:
			return _resolve_palette_color("solid", Color(0.20, 0.22, 0.28, 1.0))
		TileConstants.TileType.BREAKABLE_BLOCK:
			return _resolve_palette_color("breakable", Color(0.70, 0.50, 0.28, 1.0))
		TileConstants.TileType.SPAWN:
			return _resolve_palette_color("spawn", Color(0.24, 0.42, 0.26, 1.0))
		_:
			return _resolve_palette_color("ground", Color(0.88, 0.88, 0.82, 1.0))


func _resolve_palette_color(key: String, fallback: Color) -> Color:
	var color_value = _tile_palette.get(key, fallback)
	if color_value is Color:
		return color_value
	return fallback
