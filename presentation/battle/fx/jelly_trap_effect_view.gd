class_name JellyTrapEffectView
extends Node2D

const VfxAnimationSetLoaderScript = preload("res://content/vfx_animation_sets/runtime/vfx_animation_set_loader.gd")
const JELLY_OVERLAY_ALPHA := 0.58

@onready var _sprite: AnimatedSprite2D = get_node_or_null("EffectSprite")

var _vfx_set: Resource = null
var _release_requested: bool = false


func setup(vfx_set_id: String) -> bool:
	_ensure_sprite()
	_vfx_set = VfxAnimationSetLoaderScript.load_vfx_set(vfx_set_id)
	if _vfx_set == null:
		return false
	_sprite.sprite_frames = _vfx_set.sprite_frames
	_sprite.centered = false
	_sprite.position = -_vfx_set.pivot
	_sprite.self_modulate = Color(1.0, 1.0, 1.0, JELLY_OVERLAY_ALPHA)
	return true


func play_enter_then_loop() -> void:
	_ensure_sprite()
	if _sprite.sprite_frames == null:
		return
	_release_requested = false
	if _sprite.sprite_frames.has_animation("enter"):
		_sprite.play("enter")
	else:
		play_loop()


func play_loop() -> void:
	_ensure_sprite()
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("loop"):
		_sprite.play("loop")


func play_release() -> void:
	_ensure_sprite()
	_release_requested = true
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("release"):
		_sprite.play("release")
	else:
		queue_free()


func _ready() -> void:
	_ensure_sprite()
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = get_node_or_null("EffectSprite") as AnimatedSprite2D
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "EffectSprite"
		add_child(_sprite)


func _on_animation_finished() -> void:
	if _sprite == null:
		return
	if _release_requested:
		queue_free()
		return
	if String(_sprite.animation) == "enter":
		play_loop()
