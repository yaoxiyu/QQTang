# 角色：
# 胜负条件系统，判断对局是否结束
#
# 读写边界：
# - 读：存活玩家数
# - 写：MatchState.phase, winner 信息
#
# 禁止事项：
# - 不在这里做复杂模式判定

class_name WinConditionSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "WinConditionSystem"

func execute(ctx: SimContext) -> void:
	# 只在进行中检查
	if ctx.state.match_state.phase != MatchState.Phase.PLAYING:
		return

	# 获取存活玩家数
	var alive_count = ctx.queries.get_alive_player_count()

	# 如果存活玩家数 <= 1，结束对局
	if alive_count <= 1:
		ctx.state.match_state.phase = MatchState.Phase.ENDED

		if alive_count == 1:
			# 找到唯一存活者
			for player_id in ctx.state.indexes.living_player_ids:
				var player = ctx.queries.get_player(player_id)
				if player != null and player.alive:
					ctx.state.match_state.winner_player_id = player_id
					ctx.state.match_state.winner_team_id = player.team_id
					break
		else:
			# 0 人存活，平局
			ctx.state.match_state.winner_player_id = -1
			ctx.state.match_state.winner_team_id = -1

		ctx.state.match_state.ended_reason = MatchState.EndReason.LAST_SURVIVOR

		# TODO: 推送 MatchEndedEvent
