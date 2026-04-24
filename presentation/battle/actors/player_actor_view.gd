class_name BattlePlayerActorView
extends Node2D

const SkinApplierScript = preload("res://presentation/runtime/skin_applier.gd")
const CharacterPresentationDefScript = preload("res://content/characters/defs/character_presentation_def.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")

const PLAYER_Z_INDEX := 20
const LOCAL_VISUAL_LERP_SPEED := 16.0
const REMOTE_VISUAL_LERP_SPEED := 22.0
const TELEPORT_SNAP_DISTANCE_CELLS := 1.5
const DEBUG_APPLY_VIEW_STATE_LOG := false

var player_id: int = -1
var player_slot: int = 0
var alive: bool = true
var facing: int = 0

var _body_view: Node2D = null
var _last_view_state: Dictionary = {}
var _visual_profile = null
var _target_position: Vector2 = Vector2.ZERO
var _has_visual_target: bool = false
var _is_local_player: bool = false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not _has_visual_target:
		return
	var lerp_speed := LOCAL_VISUAL_LERP_SPEED if _is_local_player else REMOTE_VISUAL_LERP_SPEED
	position = position.lerp(_target_position, min(delta * lerp_speed, 1.0))


func apply_view_state(view_state: Dictionary) -> void:
	player_id = int(view_state.get("entity_id", -1))
	player_slot = int(view_state.get("player_slot", 0))
	_is_local_player = bool(view_state.get("is_local_player", false))
	alive = bool(view_state.get("alive", true))
	facing = int(view_state.get("facing", 0))
	_target_position = view_state.get("position", Vector2.ZERO)
	var cell_size := float(view_state.get("cell_size", 48.0))
	var snap_distance := cell_size * TELEPORT_SNAP_DISTANCE_CELLS
	var should_snap := not _has_visual_target or position.distance_to(_target_position) >= snap_distance
	if should_snap:
		position = _target_position
	if DEBUG_APPLY_VIEW_STATE_LOG:
		LogPresentationScript.debug(
			"apply_view_state entity_id=%d pose_state=%s alive=%s position=%s target=%s should_snap=%s" % [
				player_id,
				String(view_state.get("pose_state", "normal")),
				str(alive),
				str(position),
				str(_target_position),
				str(should_snap),
			],
			"",
			0,
			"presentation.actor.player"
		)
	_has_visual_target = true
	z_as_relative = false
	z_index = PLAYER_Z_INDEX
	_last_view_state = view_state.duplicate(true)

	if _body_view != null and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)


func configure_visual_profile(visual_profile) -> void:
	if _visual_profile == visual_profile:
		return
	_visual_profile = visual_profile
	_rebuild_body_view()


func _rebuild_body_view() -> void:
	if _body_view != null:
		remove_child(_body_view)
		_body_view.queue_free()
		_body_view = null

	if _visual_profile == null:
		return

	var character_presentation: CharacterPresentationDef = _read_profile_value("character_presentation") as CharacterPresentationDef
	if character_presentation == null or character_presentation.body_scene == null:
		push_error("BattlePlayerActorView missing character body_scene for slot=%d" % player_slot)
		return

	var body_instance: Node = character_presentation.body_scene.instantiate()
	if body_instance == null or not body_instance is Node2D:
		push_error("BattlePlayerActorView failed to instantiate body view for slot=%d" % player_slot)
		return

	_body_view = body_instance as Node2D
	add_child(_body_view)

	var animation_set = _read_profile_value("animation_set")
	if _body_view.has_method("setup_from_animation_set"):
		_body_view.setup_from_animation_set(animation_set)

	var character_skin = _read_profile_value("character_skin")
	if character_skin != null:
		SkinApplierScript.new().apply_character_skin(_body_view, character_skin)

	if not _last_view_state.is_empty() and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)


func _read_profile_value(key: String):
	if _visual_profile == null:
		return null
	if _visual_profile is Dictionary:
		return (_visual_profile as Dictionary).get(key, null)
	return _visual_profile.get(key)
