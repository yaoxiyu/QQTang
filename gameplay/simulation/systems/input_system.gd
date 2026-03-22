# 角色：
# 输入系统，处理玩家输入命令
#
# 读写边界：
# - 读：InputBuffer
# - 写：PlayerState.last_applied_command
#
# 禁止事项：
# - 不移动玩家
# - 不放泡泡
# - 不直接改变胜负

class_name InputSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "InputSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃玩家
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		# 从输入帧获取该玩家的命令
		var cmd = ctx.commands.get_command(player.player_slot)
		player.last_applied_command = cmd
		ctx.state.players.update_player(player)
