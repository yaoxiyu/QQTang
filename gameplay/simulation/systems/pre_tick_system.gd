# 角色：
# 预 Tick 系统，清空上一 Tick 的临时数据
#
# 读写边界：
# - 写：SimScratch, SimWorksets, SimEventBuffer
#
# 禁止事项：
# - 不能在这里做规则推进
# - 不能修改玩家位置

class_name PreTickSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "PreTickSystem"

func execute(ctx: SimContext) -> void:
	# 清空 scratch
	ctx.scratch.clear()

	# 清空 worksets
	ctx.worksets.clear()

	# 开始新 Tick 的事件
	ctx.events.begin_tick(ctx.tick)

	_tick_player_timers(ctx)


func _tick_player_timers(ctx: SimContext) -> void:
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		var changed := false
		if player.invincible_ticks > 0:
			player.invincible_ticks -= 1
			changed = true
		if player.shield_ticks > 0:
			player.shield_ticks -= 1
			changed = true
		if player.stun_ticks > 0:
			player.stun_ticks -= 1
			changed = true
		if changed:
			ctx.state.players.update_player(player)
