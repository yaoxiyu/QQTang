class_name VfxAnimationSetDef
extends Resource

@export var vfx_set_id: String = ""
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames
@export var frame_width: int = 0
@export var frame_height: int = 0
@export var enter_frames: int = 0
@export var loop_frames: int = 0
@export var release_frames: int = 0
@export var enter_fps: float = 12.0
@export var loop_fps: float = 10.0
@export var release_fps: float = 12.0
@export var pivot: Vector2 = Vector2.ZERO
@export var layer: String = "status_overlay"
@export var follow_actor: bool = true
@export var content_hash: String = ""
