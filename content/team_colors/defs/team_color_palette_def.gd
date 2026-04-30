class_name TeamColorPaletteDef
extends Resource

@export var palette_id: String = ""
@export var display_name: String = ""
@export var team_colors: Dictionary = {}
@export var content_hash: String = ""


func get_team_color(team_id: int) -> Dictionary:
	return team_colors.get(team_id, {})


func has_team(team_id: int) -> bool:
	return team_colors.has(team_id)

