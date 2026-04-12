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

	if _try_end_single_participating_team_match(ctx):
		return

	if _get_score_policy(ctx) == "team_score":
		return

	var active_team_ids := _collect_active_team_ids(ctx)
	if active_team_ids.size() > 1:
		return

	if active_team_ids.size() == 1:
		var winner_team_id := int(active_team_ids[0])
		_end_match(ctx, winner_team_id, _resolve_single_active_player_id_for_team(ctx, winner_team_id), MatchState.EndReason.TEAM_ELIMINATED)
	else:
		_end_match(ctx, -1, -1, MatchState.EndReason.TEAM_ELIMINATED)


func _end_match(ctx: SimContext, winner_team_id: int, winner_player_id: int, reason: int) -> void:
	ctx.state.match_state.phase = MatchState.Phase.ENDED
	ctx.state.match_state.winner_team_id = winner_team_id
	ctx.state.match_state.winner_player_id = winner_player_id
	ctx.state.match_state.ended_reason = reason
	var match_end_event := SimEvent.new(ctx.tick, SimEvent.EventType.MATCH_ENDED)
	match_end_event.payload = {
		"winner_player_id": ctx.state.match_state.winner_player_id,
		"winner_team_id": ctx.state.match_state.winner_team_id,
		"reason": ctx.state.match_state.ended_reason
	}
	ctx.events.push(match_end_event)


func _try_end_single_participating_team_match(ctx: SimContext) -> bool:
	var participating_team_ids := _collect_participating_team_ids(ctx)
	if participating_team_ids.size() != 1:
		return false
	var winner_team_id := int(participating_team_ids[0])
	_end_match(ctx, winner_team_id, _resolve_single_active_player_id_for_team(ctx, winner_team_id), MatchState.EndReason.LAST_SURVIVOR)
	return true


func _collect_participating_team_ids(ctx: SimContext) -> Array[int]:
	var teams: Dictionary = {}
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null or player.team_id < 1:
			continue
		teams[player.team_id] = true
	var team_ids: Array[int] = []
	for team_id in teams.keys():
		team_ids.append(int(team_id))
	team_ids.sort()
	return team_ids


func _collect_active_team_ids(ctx: SimContext) -> Array[int]:
	var teams: Dictionary = {}
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if not _is_player_active_for_team_survival(player):
			continue
		teams[player.team_id] = true
	var active_team_ids: Array[int] = []
	for team_id in teams.keys():
		active_team_ids.append(int(team_id))
	active_team_ids.sort()
	return active_team_ids


func _resolve_single_active_player_id_for_team(ctx: SimContext, team_id: int) -> int:
	var active_player_ids: Array[int] = []
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null or player.team_id != team_id:
			continue
		if not _is_player_active_for_team_survival(player):
			continue
		active_player_ids.append(player_id)
	if active_player_ids.size() == 1:
		return int(active_player_ids[0])
	return -1


func _is_player_active_for_team_survival(player: PlayerState) -> bool:
	if player == null:
		return false
	match player.life_state:
		PlayerState.LifeState.NORMAL, PlayerState.LifeState.TRAPPED, PlayerState.LifeState.REVIVING:
			return true
		_:
			return false


func _get_score_policy(ctx: SimContext) -> String:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return String(rule_flags.get("score_policy", "last_survivor"))
	return "last_survivor"
