class_name MapRuntimeLayout
extends RefCounted

var map_id: String = ""
var display_name: String = ""
var version: int = 1
var width: int = 0
var height: int = 0
var solid_cells: Array[Vector2i] = []
var breakable_cells: Array[Vector2i] = []
var mechanism_cells: Array[Vector2i] = []
var spawn_points: Array[Vector2i] = []
var item_spawn_profile_id: String = "default_items"
var item_pool_id: String = "default_items"
var content_hash: String = ""
var tile_theme_id: String = ""
var floor_tile_entries: Array[Dictionary] = []
var surface_entries: Array[Dictionary] = []
var channel_entries: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"map_id": map_id,
		"display_name": display_name,
		"version": version,
		"width": width,
		"height": height,
		"solid_cells": solid_cells.duplicate(),
		"breakable_cells": breakable_cells.duplicate(),
		"mechanism_cells": mechanism_cells.duplicate(),
		"spawn_points": spawn_points.duplicate(),
		"item_spawn_profile_id": item_spawn_profile_id,
		"item_pool_id": item_pool_id,
		"content_hash": content_hash,
		"tile_theme_id": tile_theme_id,
		"floor_tile_entries": floor_tile_entries.duplicate(true),
		"surface_entries": surface_entries.duplicate(true),
		"channel_entries": channel_entries.duplicate(true),
	}
