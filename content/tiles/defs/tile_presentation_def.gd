extends Resource
class_name TilePresentationDef

@export var presentation_id: String = ""
@export var display_name: String = ""
@export var render_role: String = ""
@export var tile_scene: PackedScene
@export var idle_anim: String = ""
@export var break_fx_scene: PackedScene
@export var height_px: float = 16.0
@export var fade_when_actor_inside: bool = false
@export var fade_alpha: float = 0.35
@export var content_hash: String = ""
