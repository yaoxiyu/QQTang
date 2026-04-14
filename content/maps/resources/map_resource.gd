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
@export var foreground_overlay_entries: Array[Dictionary] = []
@export var bound_mode_id: String = ""
@export var bound_rule_set_id: String = ""
@export var match_format_id: String = "2v2"
@export var required_team_count: int = 2
@export var max_player_count: int = 4
@export var custom_room_enabled: bool = true
@export var matchmaking_casual_enabled: bool = true
@export var matchmaking_ranked_enabled: bool = false
@export var sort_order: int = 0
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
		"bound_mode_id": bound_mode_id,
		"bound_rule_set_id": bound_rule_set_id,
		"match_format_id": match_format_id,
		"required_team_count": required_team_count,
		"max_player_count": max_player_count,
		"custom_room_enabled": custom_room_enabled,
		"matchmaking_casual_enabled": matchmaking_casual_enabled,
		"matchmaking_ranked_enabled": matchmaking_ranked_enabled,
		"sort_order": sort_order,
		"content_hash": content_hash,
	}
