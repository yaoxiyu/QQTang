extends Resource
class_name MapDef

@export var map_id: String = ""
@export var display_name: String = ""
@export var preview_image: Texture2D
@export var width: int = 13
@export var height: int = 11
@export var layout_rows: PackedStringArray = []
@export var spawn_points: Array[Vector2i] = []
@export var supported_player_count: PackedInt32Array = [2, 4]
@export var default_rule_set_id: String = ""
@export var theme_id: String = ""
