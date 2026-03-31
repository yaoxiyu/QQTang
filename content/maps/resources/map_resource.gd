class_name MapResource
extends Resource

@export var map_id: String = ""
@export var display_name: String = ""
@export var version: int = 1
@export var width: int = 0
@export var height: int = 0
@export var solid_cells: Array[Vector2i] = []
@export var breakable_cells: Array[Vector2i] = []
@export var mechanism_cells: Array[Vector2i] = []
@export var spawn_points: Array[Vector2i] = []
@export var item_spawn_profile_id: String = "default_items"
@export var tile_theme_id: String = ""
@export var content_hash: String = ""


func to_metadata() -> Dictionary:
	return {
		"map_id": map_id,
		"display_name": display_name,
		"version": version,
		"width": width,
		"height": height,
		"spawn_points": spawn_points.duplicate(),
		"item_spawn_profile_id": item_spawn_profile_id,
		"content_hash": content_hash,
	}
