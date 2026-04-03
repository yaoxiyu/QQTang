class_name CharacterPresentationDef
extends Resource

@export var presentation_id: String = ""
@export var display_name: String = ""
@export var body_scene: PackedScene
@export var animation_library_path: String = ""
@export var idle_anim: String = "idle"
@export var run_anim: String = "run"
@export var dead_anim: String = "dead"
@export var hud_portrait_small: Texture2D
@export var hud_portrait_large: Texture2D
@export var skin_anchor_slots: PackedStringArray = ["body_overlay"]
@export var actor_scene_path: String = ""
@export var portrait_small_path: String = ""
@export var portrait_large_path: String = ""
@export var hud_icon_path: String = ""
@export var spawn_fx_id: String = ""
@export var victory_fx_id: String = ""
@export var content_hash: String = ""
