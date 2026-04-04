extends Resource
class_name CharacterAnimationSetDef

@export var animation_set_id: String = ""
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames
@export var frame_width: int = 0
@export var frame_height: int = 0
@export var frames_per_direction: int = 0
@export var run_fps: float = 8.0
@export var idle_frame_index: int = 0
@export var pivot: Vector2 = Vector2.ZERO
@export var loop_run: bool = true
@export var loop_idle: bool = false
@export var content_hash: String = ""
