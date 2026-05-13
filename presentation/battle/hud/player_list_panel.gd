@tool
class_name PlayerListPanel
extends Node2D

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")
const ScoreDigitsScript = preload("res://presentation/battle/hud/score_digits.gd")
const MAX_SLOTS := 8

@export var start_y: float = 82.0
@export var slot_spacing: float = 64.0
@export var char_x: float = 610.0
@export var name_x: float = 590.0
@export var score_x: float = 680.0
@export var char_scale: float = 0.857
@export var char_clip_h: float = 56.0:
	set(v):
		char_clip_h = v
		if Engine.is_editor_hint():
			_apply_clip_h()

var _show_score: bool = false
var _slot_profiles: Array = []
var _score_digits_texture: Texture2D = null
var _pending_player_names: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_clip_h()


func _apply_clip_h() -> void:
	for ui in range(1, MAX_SLOTS + 1):
		var clip_name := "ClipChar%d" % ui
		var clip: Control = get_node_or_null(clip_name) as Control
		if clip == null:
			continue
		clip.offset_bottom = clip.offset_top + char_clip_h


# slot_0: 0-indexed slot number (matches PlayerState.player_slot and visual_profiles keys)
# ui_slot: 1-indexed for tscn node names (PH_Char1-8, ClipChar1-8, PH_Score1-8)
func _ui_slot(slot_0: int) -> int:
	return slot_0 + 1


func configure(show_score: bool, visual_profiles: Dictionary, player_names: Array[String], score_digits_texture: Texture2D = null) -> void:
	_show_score = show_score
	_score_digits_texture = score_digits_texture
	_pending_player_names = player_names.duplicate()
	_slot_profiles.resize(MAX_SLOTS)
	_slot_profiles.fill(null)

	for slot_0 in range(MAX_SLOTS):
		var profile: Variant = visual_profiles.get(slot_0, null)
		_slot_profiles[slot_0] = profile

		# Set character sprite_frames from visual profile
		var char_node := _get_char_node(slot_0)
		if char_node != null and profile != null and profile.get("animation_set") != null:
			var anim_set: Variant = profile.animation_set
			if anim_set is CharacterAnimationSetDefScript:
				char_node.sprite_frames = anim_set.sprite_frames
				char_node.speed_scale = 0.5
				_play_anim(char_node, "idle_down")

		# Set score digits texture + initial visibility
		var score_node: Control = _get_score_node(slot_0)
		if score_node != null and score_node.has_method("set_value"):
			if _score_digits_texture != null:
				score_node.set("digits_texture", _score_digits_texture)
			score_node.visible = _show_score and _has_profile_for_slot(slot_0)

	_apply_names()


func apply_battle_state(world: SimWorld) -> void:
	if world == null:
		return

	for slot_0 in range(MAX_SLOTS):
		var player := _find_player_by_slot(world, slot_0)
		var char_node := _get_char_node(slot_0)
		if char_node == null:
			continue

		if not _has_profile_for_slot(slot_0) or player == null:
			char_node.sprite_frames = null
			char_node.visible = false
		else:
			char_node.visible = true
			_update_animation(char_node, slot_0, player)

	if _show_score:
		_update_scores(world)


func _get_char_node(slot_0: int) -> AnimatedSprite2D:
	var ui := _ui_slot(slot_0)
	var clip_name := "ClipChar%d" % ui
	var clip: Control = get_node_or_null(clip_name) as Control
	if clip == null:
		return null
	return clip.get_node_or_null("PH_Char%d" % ui) as AnimatedSprite2D


func _get_score_node(slot_0: int) -> Control:
	return get_node_or_null("PH_Score%d" % _ui_slot(slot_0)) as Control


func _has_profile_for_slot(slot_0: int) -> bool:
	var profile: Variant = _slot_profiles[slot_0]
	return profile != null and profile.get("animation_set") != null


func _update_animation(char_node: AnimatedSprite2D, slot_0: int, player: PlayerState) -> void:
	var profile: Variant = _slot_profiles[slot_0]
	if profile == null:
		return

	var anim_set: Variant = profile.animation_set
	if not anim_set is CharacterAnimationSetDefScript:
		return

	if char_node.sprite_frames != anim_set.sprite_frames:
		char_node.sprite_frames = anim_set.sprite_frames
		char_node.speed_scale = 0.5

	var current_anim := ""
	if char_node.sprite_frames != null and char_node.animation in char_node.sprite_frames.get_animation_names():
		current_anim = char_node.animation

	var target_anim := "idle_down"
	match int(player.life_state):
		PlayerState.LifeState.DEAD, PlayerState.LifeState.REVIVING:
			target_anim = "dead_down"
		_:
			if not player.alive:
				target_anim = "dead_down"

	if target_anim != current_anim:
		_play_anim(char_node, target_anim)


func _play_anim(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	sprite.stop()
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play(anim_name)


func _update_scores(world: SimWorld) -> void:
	for slot_0 in range(MAX_SLOTS):
		var score_node: Control = _get_score_node(slot_0)
		if score_node == null or not score_node.has_method("set_value"):
			continue
		var player := _find_player_by_slot(world, slot_0)
		if player == null or not _has_profile_for_slot(slot_0):
			score_node.set_visible_digits(false)
			continue
		score_node.set_value(player.score)
		score_node.set_visible_digits(true)


func _apply_names() -> void:
	for slot_0 in range(MAX_SLOTS):
		var name_node: Label = get_node_or_null("NameSlot%d" % _ui_slot(slot_0)) as Label
		if name_node == null:
			continue
		if slot_0 < _pending_player_names.size() and not _pending_player_names[slot_0].is_empty():
			name_node.text = _pending_player_names[slot_0]
			name_node.visible = true
		else:
			name_node.visible = false


func _find_player_by_slot(world: SimWorld, slot_0: int) -> PlayerState:
	if world == null:
		return null
	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.player_slot == slot_0:
			return player
	return null
