class_name BattlePlayerActorView
extends Node2D

const CharacterPresentationDefScript = preload("res://content/characters/defs/character_presentation_def.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const PlayerStatusEffectViewControllerScript = preload("res://presentation/battle/actors/player_status_effect_view_controller.gd")
const PlayerIdentityMarkerSlotViewScript = preload("res://presentation/battle/actors/player_identity_marker_slot_view.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")
const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")
const ChannelVisualPolicy = preload("res://presentation/battle/policy/channel_visual_policy.gd")

const BODY_Z_INDEX := 0
const TEAM_MARKER_Z_INDEX := -10
const STATUS_EFFECT_Z_INDEX := 10
const IDENTITY_SLOT_Z_INDEX := 20
const LOCAL_VISUAL_LERP_SPEED := 16.0
const REMOTE_VISUAL_LERP_SPEED := 22.0
const TELEPORT_SNAP_DISTANCE_CELLS := 1.5
const DEBUG_APPLY_VIEW_STATE_LOG := false
const LOCAL_CONTROLLED_IDENTITY_MARKERS: Array[Dictionary] = [
	{
		"id": "local_controlled",
		"visibility": "local_only",
		"anim_dir": "res://external/assets/derived/assets/animation/misc/misc121_stand",
		"anim_name": "stand",
		"fps": 10.0,
		"loop": true,
		"offset_cells": Vector2(0.0, 50),
		"z_index": IDENTITY_SLOT_Z_INDEX,
		"require_alive": false,
	},
]
var player_id: int = -1
var player_slot: int = 0
var alive: bool = true
var facing: int = 0

var _body_view: Node2D = null
var _team_marker_view: Node2D = null
var _status_effect_controller: Node2D = null
var _identity_marker_slot_view: Node2D = null
var _last_view_state: Dictionary = {}
var _visual_profile = null
var _target_position: Vector2 = Vector2.ZERO
var _has_visual_target: bool = false
var _is_local_player: bool = false
var _channel_pass_mask_by_cell: Dictionary = {}
var _surface_virtual_z_by_cell: Dictionary = {}
var _surface_row_max_z: Dictionary = {}
var _surface_render_z_by_cell: Dictionary = {}
var _surface_occlusion_by_cell: Dictionary = {}
var _last_depth_reason: String = "base"


func _ready() -> void:
	_ensure_identity_marker_slot_view()
	set_process(true)


func _process(delta: float) -> void:
	if not _has_visual_target:
		return
	var lerp_speed: float = LOCAL_VISUAL_LERP_SPEED if _is_local_player else REMOTE_VISUAL_LERP_SPEED
	position = position.lerp(_target_position, min(delta * lerp_speed, 1.0))


func apply_view_state(view_state: Dictionary) -> void:
	player_id = int(view_state.get("entity_id", -1))
	player_slot = int(view_state.get("player_slot", 0))
	_is_local_player = bool(view_state.get("is_local_player", false))
	alive = bool(view_state.get("alive", true))
	facing = int(view_state.get("facing", 0))
	_target_position = view_state.get("position", Vector2.ZERO)
	var cell_size := float(view_state.get("cell_size", 40.0))
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
	var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	var cell_offset_y := int((view_state.get("offset", Vector2.ZERO) as Vector2).y)
	var resolved_player_z := BattleDepth.player_z(cell, 0, cell_offset_y)
	_last_view_state = view_state.duplicate(true)
	_apply_channel_occlusion_state()
	var ch_cell_size: float = float(_last_view_state.get("cell_size", 40.0))
	var collision_center: Vector2 = _resolve_collision_center(_last_view_state, ch_cell_size)
	var world_cell := Vector2i(int(floor(collision_center.x / ch_cell_size)), int(floor(collision_center.y / ch_cell_size)))
	var depth_candidates := _build_surface_depth_candidates(cell, world_cell, collision_center, ch_cell_size)
	var depth_resolve := ChannelVisualPolicy.resolve_player_z(
		resolved_player_z,
		cell,
		depth_candidates,
		_surface_occlusion_by_cell,
		_surface_row_max_z
	)
	resolved_player_z = int(depth_resolve.get("z", resolved_player_z))
	_last_depth_reason = String(depth_resolve.get("reason", "base"))
	_last_view_state["depth_reason"] = _last_depth_reason
	z_index = resolved_player_z
	if _body_view != null and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)
	if _team_marker_view != null and _team_marker_view.has_method("apply_actor_state"):
		_team_marker_view.apply_actor_state(_last_view_state)
	if _status_effect_controller != null and _status_effect_controller.has_method("apply_actor_state"):
		_status_effect_controller.apply_actor_state(_last_view_state)
	if _identity_marker_slot_view != null and _identity_marker_slot_view.has_method("apply_actor_state"):
		_identity_marker_slot_view.apply_actor_state(_last_view_state)


func configure_channel_occlusion(channel_pass_mask_by_cell: Dictionary) -> void:
	_channel_pass_mask_by_cell = channel_pass_mask_by_cell.duplicate()


func configure_surface_priority_map(surface_virtual_z_by_cell: Dictionary) -> void:
	_surface_virtual_z_by_cell = surface_virtual_z_by_cell.duplicate()


func configure_surface_row_priority_map(surface_row_max_z: Dictionary) -> void:
	_surface_row_max_z = surface_row_max_z.duplicate()


func configure_surface_render_z_by_cell(surface_render_z_by_cell: Dictionary) -> void:
	_surface_render_z_by_cell = surface_render_z_by_cell.duplicate()


func configure_surface_occlusion_by_cell(surface_occlusion_by_cell: Dictionary) -> void:
	_surface_occlusion_by_cell = surface_occlusion_by_cell.duplicate(true)


func _apply_channel_occlusion_state() -> void:
	# Intention: keep this as a generic hook so later we can hide additional render parts, not only body sprite.
	var cell_size: float = float(_last_view_state.get("cell_size", 40.0))
	var collision_center: Vector2 = _resolve_collision_center(_last_view_state, cell_size)
	_last_view_state["hide_body_sprite"] = _should_hide_in_channel(collision_center, cell_size)
	_last_view_state["depth_reason"] = _last_depth_reason


func _resolve_collision_center(view_state: Dictionary, cell_size: float) -> Vector2:
	var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	var offset := view_state.get("offset", Vector2.ZERO) as Vector2
	return Vector2(
		(float(cell.x) + 0.5) * cell_size + (offset.x / float(WorldMetrics.CELL_UNITS)) * cell_size,
		(float(cell.y) + 0.5) * cell_size + (offset.y / float(WorldMetrics.CELL_UNITS)) * cell_size
	)




func _should_hide_in_channel(world_position: Vector2, p_cell_size: float) -> bool:
	return ChannelVisualPolicy.resolve_player_body_hidden(world_position, p_cell_size, _channel_pass_mask_by_cell)


func _candidate_channel_cells(current_cell: Vector2i) -> Array[Vector2i]:
	return [
		current_cell,
		current_cell + Vector2i.LEFT,
		current_cell + Vector2i.RIGHT,
		current_cell + Vector2i.UP,
		current_cell + Vector2i.DOWN,
	]


func _build_surface_depth_candidates(
	player_cell: Vector2i,
	world_cell: Vector2i,
	collision_center: Vector2,
	cell_size: float
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	var safe_cell_size := maxf(cell_size, 1.0)
	# Only include nearby candidate cells to avoid pulling the player above
	# unrelated next-row surfaces.
	var include_dist_sq := (safe_cell_size * 0.76) * (safe_cell_size * 0.76)
	var seed_cells: Array[Vector2i] = [
		player_cell,
		world_cell,
		world_cell + Vector2i.LEFT,
		world_cell + Vector2i.RIGHT,
		world_cell + Vector2i.UP,
		world_cell + Vector2i.DOWN,
	]
	for channel_cell in _candidate_channel_cells(world_cell):
		seed_cells.append(channel_cell)
	for candidate in seed_cells:
		if seen.has(candidate):
			continue
		var candidate_center := Vector2((float(candidate.x) + 0.5) * safe_cell_size, (float(candidate.y) + 0.5) * safe_cell_size)
		if collision_center.distance_squared_to(candidate_center) > include_dist_sq:
			continue
		seen[candidate] = true
		candidates.append(candidate)
	return candidates

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
	if _team_marker_view != null:
		remove_child(_team_marker_view)
		_team_marker_view.queue_free()
		_team_marker_view = null

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
	_body_view.z_as_relative = true
	_body_view.z_index = BODY_Z_INDEX
	add_child(_body_view)
	_rebuild_team_marker_view(character_presentation)
	_rebuild_status_effect_controller()
	_ensure_identity_marker_slot_view()

	var animation_set = _read_profile_value("animation_set")
	if _body_view.has_method("setup_from_animation_set"):
		_body_view.setup_from_animation_set(animation_set)

	if not _last_view_state.is_empty() and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)
	if not _last_view_state.is_empty() and _team_marker_view != null:
		_team_marker_view.apply_actor_state(_last_view_state)
	if not _last_view_state.is_empty() and _status_effect_controller != null:
		_status_effect_controller.apply_actor_state(_last_view_state)
	if not _last_view_state.is_empty() and _identity_marker_slot_view != null:
		_identity_marker_slot_view.apply_actor_state(_last_view_state)


func _rebuild_team_marker_view(character_presentation: CharacterPresentationDef) -> void:
	if int(_read_profile_value("character_type")) != 4:
		return
	var team_id := int(_read_profile_value("team_id"))
	if team_id < 1:
		return
	var marker_animation_set := CharacterAnimationSetLoaderScript.load_animation_set("team_marker_leg1_team_%02d" % team_id)
	if marker_animation_set == null:
		return
	var marker_instance: Node = character_presentation.body_scene.instantiate()
	if marker_instance == null or not marker_instance is Node2D:
		return
	_team_marker_view = marker_instance as Node2D
	_team_marker_view.z_as_relative = true
	_team_marker_view.z_index = TEAM_MARKER_Z_INDEX
	add_child(_team_marker_view)
	if _team_marker_view.has_method("setup_from_animation_set"):
		_team_marker_view.setup_from_animation_set(marker_animation_set)


func _rebuild_status_effect_controller() -> void:
	if _status_effect_controller != null:
		remove_child(_status_effect_controller)
		_status_effect_controller.queue_free()
		_status_effect_controller = null
	_status_effect_controller = PlayerStatusEffectViewControllerScript.new()
	_status_effect_controller.name = "StatusEffectRoot"
	_status_effect_controller.z_as_relative = true
	_status_effect_controller.z_index = STATUS_EFFECT_Z_INDEX
	add_child(_status_effect_controller)


func _ensure_identity_marker_slot_view() -> void:
	if _identity_marker_slot_view != null:
		return
	_identity_marker_slot_view = PlayerIdentityMarkerSlotViewScript.new()
	_identity_marker_slot_view.name = "IdentityMarkerSlot"
	_identity_marker_slot_view.z_as_relative = true
	_identity_marker_slot_view.z_index = IDENTITY_SLOT_Z_INDEX
	if _identity_marker_slot_view.has_method("set_marker_definitions"):
		_identity_marker_slot_view.set_marker_definitions(LOCAL_CONTROLLED_IDENTITY_MARKERS)
	add_child(_identity_marker_slot_view)


func _read_profile_value(key: String):
	if _visual_profile == null:
		return null
	if _visual_profile is Dictionary:
		return (_visual_profile as Dictionary).get(key, null)
	return _visual_profile.get(key)
