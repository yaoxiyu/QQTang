class_name PlayerListPanel
extends Node2D

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")
const ScoreDigitsScript = preload("res://presentation/battle/hud/score_digits.gd")
const MAX_SLOTS := 8

@export var start_y: float = 82.0
@export var slot_spacing: float = 64.0
@export var char_x: float = 610.0
@export var rank_x: float = 620.0
@export var name_x: float = 590.0
@export var score_x: float = 680.0
@export var char_scale: float = 0.857

var _show_score: bool = false
var _slot_sprites: Array[AnimatedSprite2D] = []
var _slot_ranks: Array[Sprite2D] = []
var _slot_names: Array[Label] = []
var _slot_profiles: Array = []
var _score_displays: Array = []
var _score_digits_texture: Texture2D = null
var _pending_player_names: Array[String] = []
var _clip_containers: Array[Control] = []


func configure(show_score: bool, visual_profiles: Dictionary, player_names: Array[String], score_digits_texture: Texture2D = null) -> void:
	_show_score = show_score
	_score_digits_texture = score_digits_texture
	_pending_player_names = player_names.duplicate()
	_remove_runtime_children()
	_slot_sprites.clear()
	_slot_ranks.clear()
	_slot_names.clear()
	_slot_profiles.clear()
	_score_displays.clear()
	_build_slots(visual_profiles)


func apply_battle_state(world: SimWorld) -> void:
	if world == null:
		return

	for slot_index in range(1, MAX_SLOTS + 1):
		var player := _find_player_by_slot(world, slot_index)
		_update_slot_animation(slot_index, player)

	if _show_score:
		_update_score_displays(world)


func _ensure_clip(slot_index: int) -> Control:
	var clip_name := "ClipChar%d" % slot_index
	var clip: Control = get_node_or_null(clip_name) as Control
	if clip == null:
		clip = Control.new()
		clip.name = clip_name
		clip.anchor_left = 0.0
		clip.anchor_top = 0.0
		clip.anchor_right = 0.0
		clip.anchor_bottom = 0.0
		clip.offset_left = char_x - 28.0
		clip.offset_top = _slot_y(slot_index) - 28.0
		clip.offset_right = char_x + 28.0
		clip.offset_bottom = _slot_y(slot_index) + 28.0
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
	return clip


func _remove_runtime_children() -> void:
	for child in get_children():
		if child is AnimatedSprite2D or child is Sprite2D or child is Label:
			child.queue_free()
	for clip in _clip_containers:
		if clip != null and is_instance_valid(clip):
			for child in clip.get_children():
				if child is AnimatedSprite2D or child is Sprite2D:
					child.queue_free()


func _build_slots(visual_profiles: Dictionary) -> void:
	_clip_containers.clear()
	for slot_index in range(1, MAX_SLOTS + 1):
		_clip_containers.append(_ensure_clip(slot_index))

	_slot_profiles.resize(MAX_SLOTS + 1)
	_slot_profiles.fill(null)

	for slot_index in range(1, MAX_SLOTS + 1):
		var profile: Variant = visual_profiles.get(slot_index, null)
		_slot_profiles[slot_index] = profile

		# Character animation sprite — clipped per slot
		var clip := _clip_containers[slot_index - 1]
		var char_sprite := AnimatedSprite2D.new()
		char_sprite.name = "CharSlot%d" % slot_index
		char_sprite.centered = true
		char_sprite.position = Vector2(char_x - clip.offset_left, _slot_y(slot_index) - clip.offset_top)
		char_sprite.scale = Vector2.ONE * char_scale
		clip.add_child(char_sprite)
		_slot_sprites.append(char_sprite)

		if profile != null and profile.get("animation_set") != null:
			var anim_set: Variant = profile.animation_set
			if anim_set is CharacterAnimationSetDefScript:
				char_sprite.sprite_frames = anim_set.sprite_frames
				char_sprite.speed_scale = 0.5
				_play_animation(char_sprite, "idle_down")

		# Rank placeholder sprite
		var rank_sprite := Sprite2D.new()
		rank_sprite.name = "RankSlot%d" % slot_index
		rank_sprite.centered = true
		rank_sprite.position = Vector2(rank_x, _slot_y(slot_index))
		rank_sprite.visible = false
		add_child(rank_sprite)
		_slot_ranks.append(rank_sprite)

		# Name label
		var name_label := Label.new()
		name_label.name = "NameSlot%d" % slot_index
		name_label.anchor_left = 0.0
		name_label.anchor_top = 0.0
		name_label.anchor_right = 0.0
		name_label.anchor_bottom = 0.0
		name_label.offset_left = name_x - 40.0
		name_label.offset_top = _slot_y(slot_index) - 8.0
		name_label.offset_right = name_x
		name_label.offset_bottom = _slot_y(slot_index) + 8.0
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.visible = false
		add_child(name_label)
		_slot_names.append(name_label)

		# Score display per slot
		if _show_score:
			_create_score_display_for_slot(slot_index)

	_apply_pending_names()


func _apply_pending_names() -> void:
	for slot_index in range(1, min(_pending_player_names.size(), MAX_SLOTS) + 1):
		var name_str: String = _pending_player_names[slot_index - 1]
		if not name_str.is_empty():
			var name_idx := slot_index - 1
			if name_idx < _slot_names.size():
				_slot_names[name_idx].text = name_str
				_slot_names[name_idx].visible = true


func _slot_y(slot_index: int) -> float:
	return start_y + float(slot_index - 1) * slot_spacing


func _create_score_display_for_slot(slot_index: int) -> void:
	var digits: Control = ScoreDigitsScript.new()
	digits.name = "ScoreSlot%d" % slot_index
	digits.anchor_left = 0.0
	digits.anchor_top = 0.0
	digits.anchor_right = 0.0
	digits.anchor_bottom = 0.0
	digits.offset_left = score_x
	digits.offset_top = _slot_y(slot_index) - 9.0
	digits.offset_right = score_x + 72.0
	digits.offset_bottom = _slot_y(slot_index) + 9.0
	if digits.has_method("set_value"):
		digits.set("digits_texture", _score_digits_texture)
	add_child(digits)
	_score_displays.append(digits)


func _update_slot_animation(slot_index: int, player: PlayerState) -> void:
	var sprite_index := slot_index - 1
	if sprite_index < 0 or sprite_index >= _slot_sprites.size():
		return

	var sprite := _slot_sprites[sprite_index]
	if sprite == null or not is_instance_valid(sprite):
		return

	var profile: Variant = _slot_profiles[slot_index]
	if profile == null or profile.get("animation_set") == null:
		sprite.sprite_frames = null
		return

	var anim_set: Variant = profile.animation_set
	if not anim_set is CharacterAnimationSetDefScript:
		return

	if sprite.sprite_frames != anim_set.sprite_frames:
		sprite.sprite_frames = anim_set.sprite_frames
		sprite.speed_scale = 0.5

	if player == null:
		_play_animation(sprite, "idle_down")
		return

	var current_anim := ""
	if sprite.sprite_frames != null and sprite.animation in sprite.sprite_frames.get_animation_names():
		current_anim = sprite.animation

	var target_anim := _resolve_target_animation(player)
	if target_anim != current_anim:
		_play_animation(sprite, target_anim)


func _resolve_target_animation(player: PlayerState) -> String:
	match int(player.life_state):
		PlayerState.LifeState.DEAD:
			return "dead_down"
		PlayerState.LifeState.REVIVING:
			return "dead_down"
		_:
			if not player.alive:
				return "dead_down"
			return "idle_down"


func _play_animation(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	sprite.stop()
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play(anim_name)


func _update_score_displays(world: SimWorld) -> void:
	var slot_team_map: Dictionary = {}
	for slot_index in range(1, MAX_SLOTS + 1):
		var player := _find_player_by_slot(world, slot_index)
		if player != null and player.team_id > 0:
			slot_team_map[slot_index] = player.team_id

	var team_scores: Dictionary = {}
	for team_id in slot_team_map.values():
		if not team_scores.has(team_id):
			team_scores[team_id] = int(world.state.mode.team_scores.get(team_id, 0))

	for slot_index in range(1, MAX_SLOTS + 1):
		var display_idx := slot_index - 1
		if display_idx < 0 or display_idx >= _score_displays.size():
			continue
		var team_id: int = int(slot_team_map.get(slot_index, -1))
		var digits_control = _score_displays[display_idx]
		if team_id < 0 or not digits_control.has_method("set_value"):
			digits_control.set_visible_digits(false)
			continue
		var score: int = int(team_scores.get(team_id, 0))
		digits_control.set_value(score)
		digits_control.set_visible_digits(true)


func _find_player_by_slot(world: SimWorld, slot_index: int) -> PlayerState:
	if world == null:
		return null
	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.player_slot == slot_index:
			return player
	return null
