# 角色：
# 泡泡放置系统，处理玩家放泡命令
#
# 读写边界：
# - 读：玩家命令、bomb_available、脚下格
# - 写：BubbleState、GridState、indexes
#
# 禁止事项：
# - 不在这里处理引信和爆炸

class_name BubblePlacementSystem
extends ISimSystem

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "BubblePlacementSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃玩家
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var cmd = player.last_applied_command

		# 只处理边沿触发的 place_bubble
		var place_pressed := bool(cmd.place_bubble)
		if not place_pressed:
			player.last_place_bubble_pressed = false
			ctx.state.players.update_player(player)
			continue
		if player.last_place_bubble_pressed:
			continue
		player.last_place_bubble_pressed = true

		# 检查泡泡容量
		if player.bomb_available <= 0:
			ctx.state.players.update_player(player)
			continue

		# 检查脚下格
		var place_cell := _resolve_bubble_place_cell(player)
		var cell_x := place_cell.x
		var cell_y := place_cell.y

		# 检查当前格是否有泡泡
		var bubble_at_cell = ctx.queries.get_bubble_at(cell_x, cell_y)
		if bubble_at_cell != -1:
			ctx.state.players.update_player(player)
			continue

		# 放置泡泡
		var explode_tick = ctx.tick + player.bomb_fuse_ticks
		var bubble_id = ctx.state.bubbles.spawn_bubble(
			player_id,
			cell_x,
			cell_y,
			player.bomb_range,
			explode_tick
		)

		# 更新玩家状态
		player.bomb_available -= 1
		ctx.state.players.update_player(player)

		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			for overlap_player_id in ctx.state.players.active_ids:
				if ctx.queries.is_player_overlapping_bubble(overlap_player_id, bubble_id):
					if not bubble.ignore_player_ids.has(overlap_player_id):
						bubble.ignore_player_ids.append(overlap_player_id)
			bubble.ignore_player_ids.sort()
			ctx.state.bubbles.update_bubble(bubble)

		# 增量更新泡泡索引，保证同 Tick 内可被查询到
		if ctx.state.grid.is_in_bounds(cell_x, cell_y):
			var cell_idx := ctx.state.grid.to_cell_index(cell_x, cell_y)
			if cell_idx >= 0 and cell_idx < ctx.state.indexes.bubbles_by_cell.size():
				ctx.state.indexes.bubbles_by_cell[cell_idx] = bubble_id
		if not ctx.state.indexes.active_bubble_ids.has(bubble_id):
			ctx.state.indexes.active_bubble_ids.append(bubble_id)

		# 推送 BubblePlacedEvent（第一版使用通用事件结构）
		var placed_event := SimEvent.new(ctx.tick, SimEvent.EventType.BUBBLE_PLACED)
		placed_event.payload = {
			"bubble_id": bubble_id,
			"owner_player_id": player_id,
			"cell_x": cell_x,
			"cell_y": cell_y,
			"explode_tick": explode_tick
		}
		ctx.events.push(placed_event)


func _resolve_bubble_place_cell(player: PlayerState) -> Vector2i:
	var abs_pos := GridMotionMath.get_player_abs_pos(player)
	match player.facing:
		PlayerState.FacingDir.RIGHT:
			return Vector2i(
				_resolve_forward_axis_cell(abs_pos.x, true, _bubble_forward_window_units(player)),
				_resolve_lateral_axis_cell(abs_pos.y, true)
			)
		PlayerState.FacingDir.LEFT:
			return Vector2i(
				_resolve_forward_axis_cell(abs_pos.x, false, _bubble_forward_window_units(player)),
				_resolve_lateral_axis_cell(abs_pos.y, false)
			)
		PlayerState.FacingDir.UP:
			return Vector2i(
				_resolve_lateral_axis_cell(abs_pos.x, true),
				_resolve_forward_axis_cell(abs_pos.y, false, _bubble_forward_window_units(player))
			)
		_:
			return Vector2i(
				_resolve_lateral_axis_cell(abs_pos.x, false),
				_resolve_forward_axis_cell(abs_pos.y, true, _bubble_forward_window_units(player))
			)


func _bubble_forward_window_units(player: PlayerState) -> int:
	var total_units := MovementTuning.movement_step_units()
	var window_step_units := MovementTuning.substep_window_units(total_units, MovementTuning.MOVEMENT_SUBSTEP_COUNT)
	return window_step_units * max(MovementTuning.BUBBLE_FORWARD_PLACE_SUBSTEP_WINDOW, 1)


func _resolve_forward_axis_cell(abs_value: int, positive_forward: bool, forward_window_units: int) -> int:
	var axis := GridMotionMath.abs_to_cell_and_offset_x(abs_value)
	var cell := int(axis["cell_x"])
	var offset := int(axis["offset_x"])
	var front_cell := cell
	var back_cell := cell

	if positive_forward:
		if offset <= 0:
			front_cell = cell
			back_cell = cell - 1
		else:
			front_cell = cell + 1
			back_cell = cell
	else:
		if offset >= 0:
			front_cell = cell
			back_cell = cell + 1
		else:
			front_cell = cell - 1
			back_cell = cell

	var front_center := GridMotionMath.get_cell_center_abs_x(front_cell)
	var front_distance : int = abs(abs_value - front_center)
	if front_distance <= forward_window_units:
		return front_cell
	return back_cell


func _resolve_lateral_axis_cell(abs_value: int, positive_right: bool) -> int:
	var axis := GridMotionMath.abs_to_cell_and_offset_x(abs_value)
	var cell := int(axis["cell_x"])
	var offset := int(axis["offset_x"])
	if offset == -GridMotionMath.HALF_CELL_UNITS:
		return cell if positive_right else cell - 1
	return cell
