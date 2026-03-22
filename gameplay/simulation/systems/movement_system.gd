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

		# 如果没有移动命令，跳过
		if move_x == 0 and move_y == 0:
			continue

		# 计算目标位置
		var target_x = player.cell_x + move_x
		var target_y = player.cell_y + move_y

		# 检查是否被阻挡
		if ctx.queries.is_move_blocked_for_player(player_id, target_x, target_y):
			# 移动被阻挡
			player.move_state = PlayerState.MoveState.BLOCKED
			continue

		# 更新玩家位置
		var old_cell_x = player.cell_x
		var old_cell_y = player.cell_y

		player.cell_x = target_x
		player.cell_y = target_y
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

		# 更新玩家存储
		ctx.state.players.update_player(player)
