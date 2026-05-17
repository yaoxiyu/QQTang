class_name BattleStateToViewMapper
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const ItemDebugLogScript = preload("res://app/logging/item_debug_log.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")
const RoomTeamPaletteScript = preload("res://app/front/room/room_team_palette.gd")
const DEBUG_REMOTE_ANIM_LOG := false
const DEBUG_POSE_MAPPER_LOG := false
const PLAYER_VISUAL_CENTER_OFFSET_RATIO := Vector2(0.0, 0.5)

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS

var _item_palette := {
	1: Color(1.0, 0.85, 0.22, 1.0),
	2: Color(0.50, 0.95, 1.0, 1.0),
	3: Color(0.70, 1.0, 0.45, 1.0),
}
var _player_style_by_slot: Dictionary = {}
var _bubble_style_by_slot: Dictionary = {}
var _bubble_color_by_slot: Dictionary = {}
var _local_player_entity_id: int = -1
var _last_player_positions: Dictionary = {}
var _match_phase: int = MatchState.Phase.BOOTSTRAP
var _winner_team_id: int = -1
var _respawn_delay_ticks: int = 0
var _death_display_ticks: int = 0


func configure_content_styles(player_style_by_slot: Dictionary, bubble_style_by_slot: Dictionary, bubble_color_by_slot: Dictionary = {}) -> void:
	_player_style_by_slot = player_style_by_slot.duplicate(true)
	_bubble_style_by_slot = bubble_style_by_slot.duplicate(true)
	_bubble_color_by_slot = bubble_color_by_slot.duplicate(true)


func set_local_player_entity_id(entity_id: int) -> void:
	_local_player_entity_id = entity_id


func build_grid_cache(world: SimWorld) -> Dictionary:
	var cells: Array[Dictionary] = []
	if world == null or world.state == null or world.state.grid == null:
		return {"cells": cells}

	var grid := world.state.grid
	for y in range(grid.height):
		for x in range(grid.width):
			var cell := grid.get_static_cell(x, y)
			cells.append({
				"x": x,
				"y": y,
				"tile_type": cell.tile_type,
				"tile_flags": cell.tile_flags,
			})

	return {"cells": cells}


func build_player_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result

	_match_phase = int(world.state.match_state.phase)
	_winner_team_id = int(world.state.match_state.winner_team_id)
	_refresh_rule_tick_windows(world)

	var player_ids := _collect_visible_player_ids(world)
	player_ids.sort()

	for player_id in player_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue

		result.append(map_player_state(player))

	return result


func build_bubble_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result

	var bubble_ids := world.state.bubbles.active_ids.duplicate()
	bubble_ids.sort()

	for bubble_id in bubble_ids:
		var bubble := world.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue

		result.append(map_bubble_state(world, bubble))

	return result


func build_item_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result
	var current_tick := int(world.state.match_state.tick)

	var item_ids := world.state.items.active_ids.duplicate()
	item_ids.sort()

	for item_id in item_ids:
		var item := world.state.items.get_item(item_id)
		if item == null or not item.alive or not item.visible:
			continue

		result.append(map_item_state(item, current_tick))

	return result


func map_player_state(player: PlayerState) -> Dictionary:
	var is_local_player := player.entity_id == _local_player_entity_id
	var input_move_x := 0
	var input_move_y := 0
	if player.last_applied_command != null:
		input_move_x = int(player.last_applied_command.move_x)
		input_move_y = int(player.last_applied_command.move_y)
	var position := _to_world_position(player.cell_x, player.cell_y) \
		+ _to_player_visual_center_offset() \
		+ _to_world_offset(player.offset_x, player.offset_y)
	var animation_state := _resolve_player_animation_state(
		player,
		position,
		is_local_player,
		input_move_x,
		input_move_y
	)
	var pose_state := _resolve_pose_state(player)
	if DEBUG_POSE_MAPPER_LOG:
		LogPresentationScript.debug(
			"map_player_state entity_id=%d life_state=%d alive=%s pose_state=%s position=%s team_id=%d" % [
				player.entity_id,
				player.life_state,
				str(player.alive),
				pose_state,
				str(position),
				player.team_id,
			],
			"",
			0,
			"presentation.pose.mapper"
		)
	if DEBUG_REMOTE_ANIM_LOG and not is_local_player:
		LogPresentationScript.debug(
			"[qq_remote_anim][mapper] entity=%d slot=%d move_state=%d facing=%d last=(%d,%d) input=(%d,%d) anim_moving=%s anim_dir=(%d,%d) pos=%s" % [
				player.entity_id,
				player.player_slot,
				player.move_state,
				player.facing,
				player.last_non_zero_move_x,
				player.last_non_zero_move_y,
				input_move_x,
				input_move_y,
				str(bool(animation_state.get("is_moving", false))),
				int(animation_state.get("move_x", 0)),
				int(animation_state.get("move_y", 0)),
				str(position),
			],
			"",
			0,
			"presentation.remote_anim.mapper"
		)
	return {
		"entity_id": player.entity_id,
		"player_slot": player.player_slot,
		"team_id": player.team_id,
		"cell_size": cell_size,
		"is_local_player": is_local_player,
		"alive": player.alive,
		"life_state": player.life_state,
		"pose_state": pose_state,
		"facing": player.facing,
		"move_state": player.move_state,
		"last_non_zero_move_x": player.last_non_zero_move_x,
		"last_non_zero_move_y": player.last_non_zero_move_y,
		"input_move_x": input_move_x,
		"input_move_y": input_move_y,
		"anim_is_moving": bool(animation_state.get("is_moving", false)),
		"anim_move_x": int(animation_state.get("move_x", 0)),
		"anim_move_y": int(animation_state.get("move_y", 0)),
		"position": position,
		"cell": Vector2i(player.cell_x, player.cell_y),
		"offset": Vector2(player.offset_x, player.offset_y),
		"color": RoomTeamPaletteScript.color_for_team(player.team_id),
		"dynamic_color_enabled": false,
		"dynamic_color": Color.WHITE,
	}


func _resolve_pose_state(player: PlayerState) -> String:
	if player == null:
		return "normal"

	if _is_match_ended():
		var winner_team_id := _get_match_winner_team_id()
		if winner_team_id >= 1:
			return "win" if player.team_id == winner_team_id else "defeat"
		return "defeat"

	match int(player.life_state):
		PlayerState.LifeState.TRAPPED:
			return "trigger"
		PlayerState.LifeState.REVIVING:
			return "dead"
		PlayerState.LifeState.DEAD:
			return "dead"
		_:
			return "normal"


func _collect_visible_player_ids(world: SimWorld) -> Array[int]:
	var player_ids: Array[int] = []
	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.alive:
			player_ids.append(player_id)
			continue
		if _is_match_ended():
			player_ids.append(player_id)
			continue
		if player.life_state == PlayerState.LifeState.REVIVING:
			if _should_show_reviving_actor(player):
				player_ids.append(player_id)
			continue
		if player.life_state == PlayerState.LifeState.DEAD and player.death_display_ticks > 0:
			player_ids.append(player_id)
	return player_ids


func _is_match_ended() -> bool:
	return _match_phase == MatchState.Phase.ENDED


func _get_match_winner_team_id() -> int:
	return _winner_team_id


func _refresh_rule_tick_windows(world: SimWorld) -> void:
	_respawn_delay_ticks = 0
	_death_display_ticks = 0
	if world == null or world.config == null:
		return
	var tick_rate: int = max(int(world.config.tick_rate), 1)
	var rule_set: Dictionary = world.config.system_flags.get("rule_set", {}) as Dictionary
	if rule_set.is_empty():
		return
	_respawn_delay_ticks = max(int(rule_set.get("respawn_delay_sec", 0)), 0) * tick_rate
	_death_display_ticks = max(int(rule_set.get("death_display_sec", 0)), 0) * tick_rate


func _should_show_reviving_actor(player: PlayerState) -> bool:
	if player == null:
		return false
	if _respawn_delay_ticks <= 0:
		return false
	var display_ticks: int = mini(_death_display_ticks, _respawn_delay_ticks)
	if display_ticks <= 0:
		return false
	var elapsed_ticks: int = _respawn_delay_ticks - max(int(player.respawn_ticks), 0)
	return elapsed_ticks < display_ticks


func map_bubble_state(world: SimWorld, bubble: BubbleState) -> Dictionary:
	var bubble_style_id := _bubble_style_for_owner(world, bubble.owner_player_id)
	return {
		"entity_id": bubble.entity_id,
		"owner_player_id": bubble.owner_player_id,
		"bubble_style_id": bubble_style_id,
		"cell_size": cell_size,
		"position": _to_world_position(bubble.cell_x, bubble.cell_y),
		"cell": Vector2i(bubble.cell_x, bubble.cell_y),
		"color": _bubble_color_for_owner(world, bubble.owner_player_id),
	}


func map_item_state(item: ItemState, current_tick: int = 0) -> Dictionary:
	var view := {
		"entity_id": item.entity_id,
		"item_type": item.item_type,
		"battle_item_id": item.battle_item_id,
		"spawn_tick": item.spawn_tick,
		"current_tick": current_tick,
		"pickup_delay_ticks": item.pickup_delay_ticks,
		"cell_size": cell_size,
		"position": _to_world_position(item.cell_x, item.cell_y),
		"cell": Vector2i(item.cell_x, item.cell_y),
		"color": _item_palette.get(item.item_type, Color(1.0, 1.0, 1.0, 1.0)),
	}
	if item.scatter_from_world_x >= 0.0 and item.scatter_from_world_y >= 0.0:
		view["scatter_from"] = Vector2(
			item.scatter_from_world_x * cell_size,
			item.scatter_from_world_y * cell_size
		)
	elif item.scatter_from_x >= 0:
		view["scatter_from"] = _to_world_position(item.scatter_from_x, item.scatter_from_y)
	ItemDebugLogScript.write("[ITEM_POS] map_view eid=%d battle_item=%s cell=(%d,%d) world_pos=(%.1f,%.1f)" % [item.entity_id, item.battle_item_id, item.cell_x, item.cell_y, view.position.x, view.position.y])
	return view


func _to_world_position(cell_x: int, cell_y: int) -> Vector2:
	return Vector2(
		(float(cell_x) + 0.5) * cell_size,
		(float(cell_y) + 0.5) * cell_size
	)


func _to_world_offset(offset_x: int, offset_y: int) -> Vector2:
	return Vector2(
		(float(offset_x) / float(WorldMetrics.CELL_UNITS)) * cell_size,
		(float(offset_y) / float(WorldMetrics.CELL_UNITS)) * cell_size
	)


func _to_player_visual_center_offset() -> Vector2:
	return PLAYER_VISUAL_CENTER_OFFSET_RATIO * cell_size


func _bubble_color_for_owner(world: SimWorld, owner_player_id: int) -> Color:
	var player := world.state.players.get_player(owner_player_id)
	if player == null:
		return Color(0.30, 0.50, 1.0, 1.0)
	var default_color: Color = RoomTeamPaletteScript.color_for_team(player.team_id).lightened(0.1)
	return _bubble_color_by_slot.get(player.player_slot, default_color)


func _bubble_style_for_owner(world: SimWorld, owner_player_id: int) -> String:
	var player := world.state.players.get_player(owner_player_id)
	if player == null:
		return ""
	return String(_bubble_style_by_slot.get(player.player_slot, ""))


func _resolve_player_animation_state(
	player: PlayerState,
	position: Vector2,
	is_local_player: bool,
	input_move_x: int,
	input_move_y: int
) -> Dictionary:
	var move_x := 0
	var move_y := 0
	var is_moving := false
	if is_local_player and (input_move_x != 0 or input_move_y != 0):
		move_x = input_move_x
		move_y = input_move_y
		is_moving = true
	elif _is_moving_state(player.move_state) and (player.last_non_zero_move_x != 0 or player.last_non_zero_move_y != 0):
		move_x = player.last_non_zero_move_x
		move_y = player.last_non_zero_move_y
		is_moving = true
	else:
		var last_position := _last_player_positions.get(player.entity_id, position) as Vector2
		var visual_delta := position - last_position
		if visual_delta.length_squared() > 1.0:
			if absf(visual_delta.x) >= absf(visual_delta.y):
				move_x = 1 if visual_delta.x > 0.0 else -1
			else:
				move_y = 1 if visual_delta.y > 0.0 else -1
			is_moving = true
	_last_player_positions[player.entity_id] = position
	return {
		"is_moving": is_moving,
		"move_x": move_x,
		"move_y": move_y,
	}


func _is_moving_state(move_state: int) -> bool:
	return move_state == 1 or move_state == 3
