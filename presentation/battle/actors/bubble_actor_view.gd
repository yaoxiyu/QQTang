class_name BattleBubbleActorView
extends Node2D

const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const BubbleAnimationSetCatalogScript = preload("res://content/bubble_animation_sets/catalog/bubble_animation_set_catalog.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")

const BUBBLE_ANIMATION_SPEED_SCALE: float = 0.5

var bubble_id: int = -1
var bubble_style_id: String = ""

var _sprite: AnimatedSprite2D = null
var _current_animation_set_id: String = ""
var _channel_pass_mask_by_cell: Dictionary = {}
var _hide_in_channel: bool = false


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	bubble_id = int(view_state.get("entity_id", -1))
	position = view_state.get("position", Vector2.ZERO)
	bubble_style_id = String(view_state.get("bubble_style_id", bubble_style_id))
	var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	_hide_in_channel = _channel_pass_mask_by_cell.has(cell)
	z_as_relative = false
	z_index = BattleDepth.bubble_z(cell)
	_refresh_visuals()


func configure_channel_occlusion(channel_pass_mask_by_cell: Dictionary) -> void:
	_channel_pass_mask_by_cell = channel_pass_mask_by_cell.duplicate()


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		add_child(_sprite)


func _refresh_visuals() -> void:
	_ensure_visuals()
	if _apply_animation_set():
		_sprite.visible = not _hide_in_channel
		return
	_sprite.visible = false




func _apply_animation_set() -> bool:
	var resolved_style_id := bubble_style_id if BubbleCatalogScript.has_bubble(bubble_style_id) else BubbleCatalogScript.get_default_bubble_id()
	if resolved_style_id.is_empty():
		return false
	var metadata := BubbleLoaderScript.load_metadata(resolved_style_id)
	if metadata.is_empty():
		push_error("BattleBubbleActorView missing bubble metadata for style=%s" % resolved_style_id)
		return false
	var animation_set_id := String(metadata.get("animation_set_id", ""))
	if animation_set_id.is_empty():
		push_error("BattleBubbleActorView missing animation_set_id for style=%s" % resolved_style_id)
		return false
	var animation_set := BubbleAnimationSetCatalogScript.get_by_id(animation_set_id)
	if animation_set == null or animation_set.sprite_frames == null:
		push_error("BattleBubbleActorView failed to load BubbleAnimationSetDef for animation_set_id=%s" % animation_set_id)
		return false
	if _current_animation_set_id != animation_set_id:
		_current_animation_set_id = animation_set_id
		_sprite.sprite_frames = animation_set.sprite_frames
	if not _sprite.sprite_frames.has_animation("idle"):
		push_error("BattleBubbleActorView animation_set missing idle animation: %s" % animation_set_id)
		return false
	if _sprite.animation != "idle" or not _sprite.is_playing():
		_sprite.play("idle")
		_sprite.speed_scale = BUBBLE_ANIMATION_SPEED_SCALE
	return true
