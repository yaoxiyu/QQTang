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
		if not cmd.place_bubble:
			continue

		# 检查泡泡容量
		if player.bomb_available <= 0:
			continue

		# 检查脚下格
		var cell_x = player.cell_x
		var cell_y = player.cell_y

		# 检查当前格是否有泡泡
		var bubble_at_cell = ctx.queries.get_bubble_at(cell_x, cell_y)
		if bubble_at_cell != -1:
			continue

		# 检查是否有玩家（包括自己）
		var players_at_cell = ctx.queries.get_players_at(cell_x, cell_y)
		if players_at_cell.size() > 0:
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

		# TODO: 推送 BubblePlacedEvent
