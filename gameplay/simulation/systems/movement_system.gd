# 角色：
# 移动系统，处理玩家移动逻辑
#
# 读写边界：
# - 读：玩家命令、格子阻挡查询
# - 写：PlayerState 位置、SimIndexes.players_by_cell
#
# 禁止事项：
# - 直接读取 Node2D.position
# - 用 physics body 做规则真相
# - 在这里放泡泡

class_name MovementSystem
extends ISimSystem

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const RailConstraint = preload("res://gameplay/simulation/movement/rail_constraint.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")

const DEBUG_MOVEMENT_SNAP := true


func get_name() -> StringName:
	return "MovementSystem"


func execute(ctx: SimContext) -> void:
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var input := _sanitize_single_axis_input(
			player.last_applied_command.move_x,
			player.last_applied_command.move_y
		)
		var move_x := input.x
		var move_y := input.y
		var old_foot_cell := PlayerLocator.get_foot_cell(player)

		if move_x == 0 and move_y == 0:
			player.move_phase_ticks = 0
			player.move_state = PlayerState.MoveState.IDLE
			ctx.state.players.update_player(player)
			continue

		player.last_non_zero_move_x = move_x
		player.last_non_zero_move_y = move_y
		_update_facing_from_input(player, move_x, move_y)

		var move_summary := _execute_move_substeps(ctx, player_id, player, move_x, move_y)
		var blocked_cell: Vector2i = move_summary["blocked_cell"]
		var was_blocked := bool(move_summary["blocked"])
		var turn_only := bool(move_summary["turn_only"])

		if turn_only:
			player.move_state = PlayerState.MoveState.TURN_ONLY
		elif was_blocked:
			player.move_state = PlayerState.MoveState.BLOCKED
		else:
			player.move_state = PlayerState.MoveState.MOVING

		ctx.state.players.update_player(player)
		_refresh_bubble_overlap_ignores(ctx, player_id)

		var new_foot_cell := PlayerLocator.get_foot_cell(player)
		_emit_cell_changed_if_needed(
			ctx,
			player_id,
			old_foot_cell.x,
			old_foot_cell.y,
			new_foot_cell.x,
			new_foot_cell.y
		)

		if was_blocked:
			_emit_blocked_event(
				ctx,
				player_id,
				old_foot_cell.x,
				old_foot_cell.y,
				blocked_cell.x,
				blocked_cell.y
			)


func _execute_move_substeps(
	ctx: SimContext,
	player_id: int,
	player: PlayerState,
	move_x: int,
	move_y: int
) -> Dictionary:
	var blocked := false
	var turn_only := false
	var blocked_cell := Vector2i.ZERO
	var fixed_step_units := MovementTuning.movement_step_units()
	var required_ticks : int = max(MovementTuning.ticks_per_step(player.speed_level), 1)
	player.move_phase_ticks += 1
	var step_count := int(player.move_phase_ticks / required_ticks)
	player.move_phase_ticks = player.move_phase_ticks % required_ticks

	for _i in range(step_count):
		var step_units := fixed_step_units

		var foot_cell := PlayerLocator.get_foot_cell(player)
		var target_cell := foot_cell + Vector2i(move_x, move_y)
		var direct_target_blocked := ctx.queries.is_transition_blocked_for_player(
			player_id,
			foot_cell.x,
			foot_cell.y,
			target_cell.x,
			target_cell.y
		)
		var rail := ctx.queries.get_player_rail_constraint(player_id, foot_cell.x, foot_cell.y)
		if not direct_target_blocked and not _try_apply_turn_snap(player, foot_cell, rail, move_x, move_y):
			turn_only = true
			break

		var move_result := _try_move_along_axis(ctx, player_id, player, move_x, move_y, step_units, fixed_step_units)
		var resolved_abs_pos: Vector2i = move_result["abs_pos"]
		GridMotionMath.write_player_abs_pos(player, resolved_abs_pos.x, resolved_abs_pos.y)

		if bool(move_result["blocked"]):
			blocked = true
			blocked_cell = move_result["blocked_cell"]
			break

	return {
		"blocked": blocked,
		"blocked_cell": blocked_cell,
		"turn_only": turn_only,
	}


func _refresh_bubble_overlap_ignores(ctx: SimContext, player_id: int) -> void:
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue
		if not bubble.ignore_player_ids.has(player_id):
			continue
		if ctx.queries.is_player_overlapping_bubble(player_id, bubble_id):
			continue
		bubble.ignore_player_ids.erase(player_id)
		ctx.state.bubbles.update_bubble(bubble)


func _sanitize_single_axis_input(move_x: int, move_y: int) -> Vector2i:
	move_x = clampi(move_x, -1, 1)
	move_y = clampi(move_y, -1, 1)
	if move_x != 0 and move_y != 0:
		return Vector2i.ZERO
	return Vector2i(move_x, move_y)


func _update_facing_from_input(player: PlayerState, move_x: int, move_y: int) -> void:
	if move_y > 0:
		player.facing = PlayerState.FacingDir.DOWN
	elif move_y < 0:
		player.facing = PlayerState.FacingDir.UP
	elif move_x > 0:
		player.facing = PlayerState.FacingDir.RIGHT
	elif move_x < 0:
		player.facing = PlayerState.FacingDir.LEFT


func _try_apply_turn_snap(
	player: PlayerState,
	foot_cell: Vector2i,
	rail: int,
	move_x: int,
	move_y: int
) -> bool:
	if rail == RailConstraint.Type.CENTER_PIVOT:
		return false

	if RailConstraint.requires_center_for_vertical_turn(rail) and move_y != 0:
		if abs(player.offset_x) > MovementTuning.turn_snap_window_units():
			return false
		var abs_pos := GridMotionMath.get_player_abs_pos(player)
		GridMotionMath.write_player_abs_pos(
			player,
			GridMotionMath.get_cell_center_abs_x(foot_cell.x),
			abs_pos.y
		)

	if RailConstraint.requires_center_for_horizontal_turn(rail) and move_x != 0:
		if abs(player.offset_y) > MovementTuning.turn_snap_window_units():
			return false
		var abs_pos := GridMotionMath.get_player_abs_pos(player)
		GridMotionMath.write_player_abs_pos(
			player,
			abs_pos.x,
			GridMotionMath.get_cell_center_abs_y(foot_cell.y)
		)

	return true


func _try_move_along_axis(
	ctx: SimContext,
	player_id: int,
	player: PlayerState,
	move_x: int,
	move_y: int,
	step_units: int,
	total_units: int
) -> Dictionary:
	var abs_pos := GridMotionMath.get_player_abs_pos(player)
	var foot_cell := PlayerLocator.get_foot_cell(player)
	var target_cell := foot_cell + Vector2i(move_x, move_y)
	var direct_target_blocked := ctx.queries.is_transition_blocked_for_player(
		player_id,
		foot_cell.x,
		foot_cell.y,
		target_cell.x,
		target_cell.y
	)
	var tentative := abs_pos + Vector2i(move_x * step_units, move_y * step_units)
	if direct_target_blocked:
		var clamped_abs_pos := _clamp_abs_to_blocked_axis_limit(tentative, foot_cell, move_x, move_y)
		var collision_blocked := clamped_abs_pos == abs_pos
		return {
			"abs_pos": clamped_abs_pos,
			"blocked": collision_blocked,
			"blocked_cell": target_cell,
		}
	var blocked_hit := _find_overlap_blocked_cell(ctx, player_id, tentative, foot_cell, target_cell, move_x, move_y)
	if not bool(blocked_hit["found"]):
		return {
			"abs_pos": tentative,
			"blocked": false,
			"blocked_cell": target_cell,
		}

	var snapped_tentative := _try_apply_lane_center_snap(
		ctx,
		player_id,
		abs_pos,
		tentative,
		foot_cell,
		target_cell,
		move_x,
		move_y,
		total_units
	)
	var snapped_blocked_hit := _find_overlap_blocked_cell(ctx, player_id, snapped_tentative, foot_cell, target_cell, move_x, move_y)
	if snapped_tentative == tentative:
		var blocked_cell: Vector2i = blocked_hit["cell"]
		return {
			"abs_pos": abs_pos,
			"blocked": true,
			"blocked_cell": blocked_cell,
		}
	if bool(snapped_blocked_hit["found"]):
		var blocked_cell: Vector2i = snapped_blocked_hit["cell"]
		return {
			"abs_pos": abs_pos,
			"blocked": true,
			"blocked_cell": blocked_cell,
		}

	if not _crosses_cell_boundary(snapped_tentative, foot_cell, move_x, move_y):
		return {
			"abs_pos": snapped_tentative,
			"blocked": false,
			"blocked_cell": target_cell,
		}

	return {
		"abs_pos": snapped_tentative,
		"blocked": false,
		"blocked_cell": target_cell,
	}


func _try_apply_lane_center_snap(
	ctx: SimContext,
	player_id: int,
	current_abs_pos: Vector2i,
	tentative_abs_pos: Vector2i,
	foot_cell: Vector2i,
	target_cell: Vector2i,
	move_x: int,
	move_y: int,
	total_units: int
) -> Vector2i:
	var snapped := tentative_abs_pos
	var pass_window_units := MovementTuning.pass_absorb_window_units()
	if move_x > 0:
		var offset_y := current_abs_pos.y - GridMotionMath.get_cell_center_abs_y(foot_cell.y)
		if offset_y == 0:
			_debug_snap("skip_centered", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, 0, false, total_units, pass_window_units)
			return snapped
		if abs(offset_y) <= pass_window_units:
			snapped.y = GridMotionMath.get_cell_center_abs_y(foot_cell.y)
			_debug_snap("snap", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_y), true, total_units, pass_window_units)
		else:
			_debug_snap("skip_window", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_y), false, total_units, pass_window_units)
	elif move_x < 0:
		var offset_y := current_abs_pos.y - GridMotionMath.get_cell_center_abs_y(foot_cell.y)
		if offset_y == 0:
			_debug_snap("skip_centered", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, 0, false, total_units, pass_window_units)
			return snapped
		if abs(offset_y) <= pass_window_units:
			snapped.y = GridMotionMath.get_cell_center_abs_y(foot_cell.y)
			_debug_snap("snap", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_y), true, total_units, pass_window_units)
		else:
			_debug_snap("skip_window", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_y), false, total_units, pass_window_units)
	elif move_y > 0:
		var offset_x := current_abs_pos.x - GridMotionMath.get_cell_center_abs_x(foot_cell.x)
		if offset_x == 0:
			_debug_snap("skip_centered", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, 0, false, total_units, pass_window_units)
			return snapped
		if abs(offset_x) <= pass_window_units:
			snapped.x = GridMotionMath.get_cell_center_abs_x(foot_cell.x)
			_debug_snap("snap", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_x), true, total_units, pass_window_units)
		else:
			_debug_snap("skip_window", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_x), false, total_units, pass_window_units)
	elif move_y < 0:
		var offset_x := current_abs_pos.x - GridMotionMath.get_cell_center_abs_x(foot_cell.x)
		if offset_x == 0:
			_debug_snap("skip_centered", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, 0, false, total_units, pass_window_units)
			return snapped
		if abs(offset_x) <= pass_window_units:
			snapped.x = GridMotionMath.get_cell_center_abs_x(foot_cell.x)
			_debug_snap("snap", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_x), true, total_units, pass_window_units)
		else:
			_debug_snap("skip_window", player_id, foot_cell, target_cell, move_x, move_y, current_abs_pos, abs(offset_x), false, total_units, pass_window_units)
	return snapped


func _debug_snap(
	stage: String,
	player_id: int,
	foot_cell: Vector2i,
	target_cell: Vector2i,
	move_x: int,
	move_y: int,
	current_abs_pos: Vector2i,
	lateral_distance_units: int,
	did_snap: bool,
	total_units: int,
	window_units: int
) -> void:
	if not DEBUG_MOVEMENT_SNAP:
		return
	print(
		"[qq_move_snap] stage=%s player=%d foot=%s target=%s move=(%d,%d) abs=%s lateral_units=%d window_units=%d snapped=%s" % [
			stage,
			player_id,
			str(foot_cell),
			str(target_cell),
			move_x,
			move_y,
			str(current_abs_pos),
			lateral_distance_units,
			window_units,
			str(did_snap)
		]
	)


func _find_overlap_blocked_cell(
	ctx: SimContext,
	player_id: int,
	abs_pos: Vector2i,
	foot_cell: Vector2i,
	target_cell: Vector2i,
	move_x: int,
	move_y: int
) -> Dictionary:
	var candidates: Array[Vector2i] = []
	if move_x != 0:
		candidates.append(Vector2i(target_cell.x, foot_cell.y - 1))
		candidates.append(Vector2i(target_cell.x, foot_cell.y + 1))
	elif move_y != 0:
		candidates.append(Vector2i(foot_cell.x - 1, target_cell.y))
		candidates.append(Vector2i(foot_cell.x + 1, target_cell.y))

	for blocked_cell in candidates:
		if not ctx.queries.is_transition_blocked_for_player(player_id, foot_cell.x, foot_cell.y, blocked_cell.x, blocked_cell.y):
			continue
		if _is_overlapping_blocked_cell(ctx, player_id, abs_pos, blocked_cell):
			return {
				"found": true,
				"cell": blocked_cell,
			}
	return {
		"found": false,
		"cell": Vector2i.ZERO,
	}


func _is_overlapping_blocked_cell(
	_ctx: SimContext,
	_player_id: int,
	abs_pos: Vector2i,
	blocked_cell: Vector2i
) -> bool:
	var blocked_center_x := GridMotionMath.get_cell_center_abs_x(blocked_cell.x)
	var blocked_center_y := GridMotionMath.get_cell_center_abs_y(blocked_cell.y)
	return abs(abs_pos.x - blocked_center_x) < GridMotionMath.CELL_UNITS and abs(abs_pos.y - blocked_center_y) < GridMotionMath.CELL_UNITS


func _get_containing_cell_center(abs_value: int) -> int:
	var result := GridMotionMath.abs_to_cell_and_offset_x(abs_value)
	return GridMotionMath.get_cell_center_abs_x(int(result["cell_x"]))


func _crosses_cell_boundary(abs_pos: Vector2i, foot_cell: Vector2i, move_x: int, move_y: int) -> bool:
	if move_x > 0:
		return abs_pos.x >= (foot_cell.x + 1) * GridMotionMath.CELL_UNITS
	if move_x < 0:
		return abs_pos.x < foot_cell.x * GridMotionMath.CELL_UNITS
	if move_y > 0:
		return abs_pos.y >= (foot_cell.y + 1) * GridMotionMath.CELL_UNITS
	if move_y < 0:
		return abs_pos.y < foot_cell.y * GridMotionMath.CELL_UNITS
	return false


func _clamp_abs_to_current_cell_boundary(
	abs_pos: Vector2i,
	foot_cell: Vector2i,
	move_x: int,
	move_y: int
) -> Vector2i:
	var clamped := abs_pos
	if move_x > 0:
		clamped.x = min(clamped.x, ((foot_cell.x + 1) * GridMotionMath.CELL_UNITS) - 1)
	elif move_x < 0:
		clamped.x = max(clamped.x, foot_cell.x * GridMotionMath.CELL_UNITS)
	elif move_y > 0:
		clamped.y = min(clamped.y, ((foot_cell.y + 1) * GridMotionMath.CELL_UNITS) - 1)
	elif move_y < 0:
		clamped.y = max(clamped.y, foot_cell.y * GridMotionMath.CELL_UNITS)
	return clamped


func _clamp_abs_to_blocked_axis_limit(
	abs_pos: Vector2i,
	foot_cell: Vector2i,
	move_x: int,
	move_y: int
) -> Vector2i:
	var clamped := abs_pos
	if move_x > 0:
		clamped.x = min(clamped.x, GridMotionMath.get_cell_center_abs_x(foot_cell.x))
	elif move_x < 0:
		clamped.x = max(clamped.x, GridMotionMath.get_cell_center_abs_x(foot_cell.x))
	elif move_y > 0:
		clamped.y = min(clamped.y, GridMotionMath.get_cell_center_abs_y(foot_cell.y))
	elif move_y < 0:
		clamped.y = max(clamped.y, GridMotionMath.get_cell_center_abs_y(foot_cell.y))
	return clamped


func _emit_cell_changed_if_needed(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	if from_x == to_x and from_y == to_y:
		return

	_update_player_cell_index(ctx, player_id, from_x, from_y, to_x, to_y)

	var moved_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_MOVED)
	moved_event.payload = {
		"player_id": player_id,
		"from_cell_x": from_x,
		"from_cell_y": from_y,
		"to_cell_x": to_x,
		"to_cell_y": to_y
	}
	ctx.events.push(moved_event)


func _emit_blocked_event(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	var blocked_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_BLOCKED)
	blocked_event.payload = {
		"player_id": player_id,
		"from_cell_x": from_x,
		"from_cell_y": from_y,
		"to_cell_x": to_x,
		"to_cell_y": to_y
	}
	ctx.events.push(blocked_event)


func _update_player_cell_index(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	if from_x == to_x and from_y == to_y:
		return

	if ctx.state.grid.is_in_bounds(from_x, from_y):
		var from_idx := ctx.state.grid.to_cell_index(from_x, from_y)
		if from_idx >= 0 and from_idx < ctx.state.indexes.players_by_cell.size():
			var from_list: Array = ctx.state.indexes.players_by_cell[from_idx]
			var pos := from_list.find(player_id)
			if pos != -1:
				from_list.remove_at(pos)

	if ctx.state.grid.is_in_bounds(to_x, to_y):
		var to_idx := ctx.state.grid.to_cell_index(to_x, to_y)
		if to_idx >= 0 and to_idx < ctx.state.indexes.players_by_cell.size():
			var to_list: Array = ctx.state.indexes.players_by_cell[to_idx]
			if not to_list.has(player_id):
				to_list.append(player_id)
