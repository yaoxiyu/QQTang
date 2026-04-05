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

const CELL_OFFSET_UNITS := 1000
const HALF_CELL_OFFSET_UNITS := CELL_OFFSET_UNITS / 2

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "MovementSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃玩家
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var cmd = player.last_applied_command

		# 只处理四方向移动
		var move_x = cmd.move_x
		var move_y = cmd.move_y

		# 忽略斜向输入
		if move_x != 0 and move_y != 0:
			move_x = 0
			move_y = 0

		if player.move_state == PlayerState.MoveState.MOVING and (player.offset_x != 0 or player.offset_y != 0):
			_continue_movement(ctx, player_id, player)
			continue

		# 如果没有移动命令，跳过
		if move_x == 0 and move_y == 0:
			if player.move_state != PlayerState.MoveState.IDLE:
				player.move_state = PlayerState.MoveState.IDLE
				ctx.state.players.update_player(player)
			continue

		# 计算目标位置
		var target_x = player.cell_x + move_x
		var target_y = player.cell_y + move_y

		# 检查是否被阻挡
		if ctx.queries.is_move_blocked_for_player(player_id, target_x, target_y):
			# 移动被阻挡
			player.move_state = PlayerState.MoveState.BLOCKED
			if move_y > 0:
				player.facing = PlayerState.FacingDir.DOWN
			elif move_y < 0:
				player.facing = PlayerState.FacingDir.UP
			elif move_x > 0:
				player.facing = PlayerState.FacingDir.RIGHT
			elif move_x < 0:
				player.facing = PlayerState.FacingDir.LEFT
			ctx.state.players.update_player(player)
			var blocked_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_BLOCKED)
			blocked_event.payload = {
				"player_id": player_id,
				"from_cell_x": player.cell_x,
				"from_cell_y": player.cell_y,
				"to_cell_x": target_x,
				"to_cell_y": target_y
			}
			ctx.events.push(blocked_event)
			continue

		var old_cell_x = player.cell_x
		var old_cell_y = player.cell_y
		var move_units := _movement_units_per_tick(player.speed_level)

		player.move_state = PlayerState.MoveState.MOVING
		player.last_non_zero_move_x = move_x
		player.last_non_zero_move_y = move_y

		# 更新面朝方向
		if move_y > 0:
			player.facing = PlayerState.FacingDir.DOWN
		elif move_y < 0:
			player.facing = PlayerState.FacingDir.UP
		elif move_x > 0:
			player.facing = PlayerState.FacingDir.RIGHT
		elif move_x < 0:
			player.facing = PlayerState.FacingDir.LEFT

		player.offset_x = move_x * move_units
		player.offset_y = move_y * move_units
		_apply_offset_rebase(player)

		if player.offset_x == 0 and player.offset_y == 0:
			player.move_state = PlayerState.MoveState.IDLE

		# 更新玩家存储
		ctx.state.players.update_player(player)

		_emit_cell_changed_if_needed(ctx, player_id, old_cell_x, old_cell_y, player.cell_x, player.cell_y)


func _continue_movement(ctx: SimContext, player_id: int, player: PlayerState) -> void:
	var move_x := player.last_non_zero_move_x
	var move_y := player.last_non_zero_move_y
	if move_x == 0 and move_y == 0:
		player.offset_x = 0
		player.offset_y = 0
		player.move_state = PlayerState.MoveState.IDLE
		ctx.state.players.update_player(player)
		return

	var old_cell_x := player.cell_x
	var old_cell_y := player.cell_y
	var move_units := _movement_units_per_tick(player.speed_level)
	player.offset_x += move_x * move_units
	player.offset_y += move_y * move_units
	_apply_offset_rebase(player)

	if player.offset_x == 0 and player.offset_y == 0:
		player.move_state = PlayerState.MoveState.IDLE
	else:
		player.move_state = PlayerState.MoveState.MOVING

	ctx.state.players.update_player(player)
	_emit_cell_changed_if_needed(ctx, player_id, old_cell_x, old_cell_y, player.cell_x, player.cell_y)


func _apply_offset_rebase(player: PlayerState) -> void:
	while player.offset_x > HALF_CELL_OFFSET_UNITS:
		player.cell_x += 1
		player.offset_x -= CELL_OFFSET_UNITS
	while player.offset_x < -HALF_CELL_OFFSET_UNITS:
		player.cell_x -= 1
		player.offset_x += CELL_OFFSET_UNITS
	while player.offset_y > HALF_CELL_OFFSET_UNITS:
		player.cell_y += 1
		player.offset_y -= CELL_OFFSET_UNITS
	while player.offset_y < -HALF_CELL_OFFSET_UNITS:
		player.cell_y -= 1
		player.offset_y += CELL_OFFSET_UNITS

	if player.offset_y == 0 and abs(player.offset_x) < _movement_units_per_tick(player.speed_level):
		player.offset_x = 0
	if player.offset_x == 0 and abs(player.offset_y) < _movement_units_per_tick(player.speed_level):
		player.offset_y = 0


func _movement_units_per_tick(speed_level: int) -> int:
	match max(speed_level, 1):
		1:
			return 250
		2:
			return 334
		3:
			return 500
		_:
			return 500


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
