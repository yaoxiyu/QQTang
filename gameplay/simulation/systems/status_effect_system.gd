# 角色：
# 状态效果系统，处理死亡/复活等状态变化
#
# 读写边界：
# - 读：players_to_kill, exploded_bubbles, immunity
# - 写：PlayerState.alive,生命状态,统计数据,bomb_available
#
# 禁止事项：
# - 不在这里做规则判断

class_name StatusEffectSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "StatusEffectSystem"

func execute(ctx: SimContext) -> void:
	# 处理死亡
	for player_id in ctx.scratch.players_to_kill:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		# 检查无敌
		if player.invincible_ticks > 0:
			continue

		# 标记死亡
		player.alive = false
		player.life_state = PlayerState.LifeState.DEAD
		player.deaths += 1

		# 更新活跃列表
		ctx.state.players.mark_player_dead(player_id)

		ctx.state.players.update_player(player)

		# TODO: 推送 PlayerKilledEvent

	# 处理爆炸泡泡返还（在死亡处理之后）
	for bubble_id in ctx.scratch.exploded_bubble_ids:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue

		var owner_id = bubble.owner_player_id
		var player = ctx.state.players.get_player(owner_id)
		if player == null or not player.alive:
			continue

		# 返还泡泡容量（直到达到最大容量）
		if player.bomb_available < player.bomb_capacity:
			player.bomb_available += 1
			ctx.state.players.update_player(player)
