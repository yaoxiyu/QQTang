class_name TileDef
extends Resource

@export var tile_id: String = ""
@export var display_name: String = ""
@export var tile_type: String = ""
@export var tile_category: String = ""
@export var scene_path: String = ""
@export var is_walkable: bool = true
@export var is_breakable: bool = false
@export var blocks_blast: bool = false
@export var blocks_movement: bool = false
@export var movement_pass_mask: int = 15
@export var blast_pass_mask: int = 15
@export var can_spawn_item: bool = false
@export var occlusion_mode: String = "none"
@export var break_fx_id: String = ""
@export var content_hash: String = ""
