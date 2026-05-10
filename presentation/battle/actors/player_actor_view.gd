class_name BattlePlayerActorView
extends Node2D

const CharacterPresentationDefScript = preload("res://content/characters/defs/character_presentation_def.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const PlayerStatusEffectViewControllerScript = preload("res://presentation/battle/actors/player_status_effect_view_controller.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")
const BattleDepth = preload("res://presentation/battle/battle_depth.gd")
const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const BODY_Z_INDEX := 0
const TEAM_MARKER_Z_INDEX := -10
const STATUS_EFFECT_Z_INDEX := 10
const LOCAL_VISUAL_LERP_SPEED := 16.0
const REMOTE_VISUAL_LERP_SPEED := 22.0
const TELEPORT_SNAP_DISTANCE_CELLS := 1.5
const DEBUG_APPLY_VIEW_STATE_LOG := false
const PASS_UP := 1
const PASS_RIGHT := 2
const PASS_DOWN := 4
const PASS_LEFT := 8

var player_id: int = -1
var player_slot: int = 0
var alive: bool = true
var facing: int = 0

var _body_view: Node2D = null
var _team_marker_view: Node2D = null
var _status_effect_controller: Node2D = null
var _last_view_state: Dictionary = {}
var _visual_profile = null
var _target_position: Vector2 = Vector2.ZERO
var _has_visual_target: bool = false
var _is_local_player: bool = false
var _channel_pass_mask_by_cell: Dictionary = {}
var _surface_virtual_z_by_cell: Dictionary = {}
var _surface_row_max_z: Dictionary = {}


func _ready() -> void:
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
	var resolved_player_z := BattleDepth.player_z(cell)
	var surface_row_z := int(_surface_row_max_z.get(cell.y, -2147483648))
	if surface_row_z >= resolved_player_z:
		resolved_player_z = surface_row_z + 1
	z_index = resolved_player_z
	_last_view_state = view_state.duplicate(true)
	_apply_channel_occlusion_state()

	if _body_view != null and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)
	if _team_marker_view != null and _team_marker_view.has_method("apply_actor_state"):
		_team_marker_view.apply_actor_state(_last_view_state)
	if _status_effect_controller != null and _status_effect_controller.has_method("apply_actor_state"):
		_status_effect_controller.apply_actor_state(_last_view_state)


func configure_channel_occlusion(channel_pass_mask_by_cell: Dictionary) -> void:
	_channel_pass_mask_by_cell = channel_pass_mask_by_cell.duplicate()


func configure_surface_priority_map(surface_virtual_z_by_cell: Dictionary) -> void:
	_surface_virtual_z_by_cell = surface_virtual_z_by_cell.duplicate()


func configure_surface_row_priority_map(surface_row_max_z: Dictionary) -> void:
	_surface_row_max_z = surface_row_max_z.duplicate()


func _apply_channel_occlusion_state() -> void:
	# Intention: keep this as a generic hook so later we can hide additional render parts, not only body sprite.
	var cell_size: float = float(_last_view_state.get("cell_size", 40.0))
	var collision_center: Vector2 = _resolve_collision_center(_last_view_state, cell_size)
	_last_view_state["hide_body_sprite"] = _should_hide_in_channel(collision_center, cell_size)


func _resolve_collision_center(view_state: Dictionary, cell_size: float) -> Vector2:
	var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	var offset := view_state.get("offset", Vector2.ZERO) as Vector2
	return Vector2(
		(float(cell.x) + 0.5) * cell_size + (offset.x / float(WorldMetrics.CELL_UNITS)) * cell_size,
		(float(cell.y) + 0.5) * cell_size + (offset.y / float(WorldMetrics.CELL_UNITS)) * cell_size
	)




func _should_hide_in_channel(world_position: Vector2, p_cell_size: float) -> bool:
	if _channel_pass_mask_by_cell.is_empty():
		return false
	var cell_size: float = maxf(p_cell_size, 1.0)
	var hide_distance_sq: float = (cell_size * 0.5) * (cell_size * 0.5)
	var current_cell := Vector2i(
		int(floor(world_position.x / cell_size)),
		int(floor(world_position.y / cell_size))
	)
	for sample_cell in _candidate_channel_cells(current_cell):
		if not _channel_pass_mask_by_cell.has(sample_cell):
			continue
		var channel_center := Vector2((float(sample_cell.x) + 0.5) * cell_size, (float(sample_cell.y) + 0.5) * cell_size)
		if world_position.distance_squared_to(channel_center) <= hide_distance_sq:
			return true
	# Keep hidden while crossing a shared edge between connected channels to avoid edge flicker.
	return _is_on_connected_channel_edge(world_position, current_cell, cell_size)


func _candidate_channel_cells(current_cell: Vector2i) -> Array[Vector2i]:
	return [
		current_cell,
		current_cell + Vector2i.LEFT,
		current_cell + Vector2i.RIGHT,
		current_cell + Vector2i.UP,
		current_cell + Vector2i.DOWN,
	]


func _is_on_connected_channel_edge(world_position: Vector2, current_cell: Vector2i, cell_size: float) -> bool:
	var epsilon := 0.001
	var x_edge: float = round(world_position.x / cell_size)
	if absf(world_position.x - x_edge * cell_size) <= epsilon:
		var left_cell := Vector2i(int(x_edge) - 1, current_cell.y)
		var right_cell := Vector2i(int(x_edge), current_cell.y)
		if _channels_connected(left_cell, right_cell, Vector2i.RIGHT):
			return true
	var y_edge: float = round(world_position.y / cell_size)
	if absf(world_position.y - y_edge * cell_size) <= epsilon:
		var up_cell := Vector2i(current_cell.x, int(y_edge) - 1)
		var down_cell := Vector2i(current_cell.x, int(y_edge))
		if _channels_connected(up_cell, down_cell, Vector2i.DOWN):
			return true
	return false


func _channels_connected(a: Vector2i, b: Vector2i, dir_from_a_to_b: Vector2i) -> bool:
	var a_mask := int(_channel_pass_mask_by_cell.get(a, -1))
	var b_mask := int(_channel_pass_mask_by_cell.get(b, -1))
	if a_mask < 0 or b_mask < 0:
		return false
	if dir_from_a_to_b == Vector2i.RIGHT:
		return (a_mask & PASS_RIGHT) != 0 and (b_mask & PASS_LEFT) != 0
	if dir_from_a_to_b == Vector2i.DOWN:
		return (a_mask & PASS_DOWN) != 0 and (b_mask & PASS_UP) != 0
	return false

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

	var animation_set = _read_profile_value("animation_set")
	if _body_view.has_method("setup_from_animation_set"):
		_body_view.setup_from_animation_set(animation_set)

	if not _last_view_state.is_empty() and _body_view.has_method("apply_actor_state"):
		_body_view.apply_actor_state(_last_view_state)
	if not _last_view_state.is_empty() and _team_marker_view != null:
		_team_marker_view.apply_actor_state(_last_view_state)
	if not _last_view_state.is_empty() and _status_effect_controller != null:
		_status_effect_controller.apply_actor_state(_last_view_state)


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


func _read_profile_value(key: String):
	if _visual_profile == null:
		return null
	if _visual_profile is Dictionary:
		return (_visual_profile as Dictionary).get(key, null)
	return _visual_profile.get(key)
