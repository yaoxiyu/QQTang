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
var content_hash: String = ""
var tile_theme_id: String = ""


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
		"content_hash": content_hash,
		"tile_theme_id": tile_theme_id,
	}
