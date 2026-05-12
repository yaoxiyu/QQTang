class_name TimeLimitSystem
extends ISimSystem


func get_name() -> StringName:
	return "TimeLimitSystem"


func execute(ctx: SimContext) -> void:
	if ctx.state.match_state.phase != MatchState.Phase.PLAYING:
		return
	if ctx.state.match_state.remaining_ticks <= 0:
		return

	ctx.state.match_state.remaining_ticks -= 1
	if ctx.state.match_state.remaining_ticks > 0:
		return

	ctx.state.match_state.phase = MatchState.Phase.ENDED
	ctx.state.match_state.ended_reason = MatchState.EndReason.TIME_UP
	if _can_revive(ctx):
		_apply_team_score_time_up_result(ctx)
	else:
		_apply_non_score_time_up_result(ctx)

	var match_end_event := SimEvent.new(ctx.tick, SimEvent.EventType.MATCH_ENDED)
	match_end_event.payload = {
		"winner_player_id": ctx.state.match_state.winner_player_id,
		"winner_team_id": ctx.state.match_state.winner_team_id,
		"reason": ctx.state.match_state.ended_reason,
	}
	ctx.events.push(match_end_event)


func _apply_team_score_time_up_result(ctx: SimContext) -> void:
	var participating_team_ids := _collect_participating_team_ids(ctx)
	if participating_team_ids.is_empty():
		ctx.state.match_state.winner_player_id = -1
		ctx.state.match_state.winner_team_id = -1
		return

	var highest_score := -2147483648
	var leader_team_ids: Array[int] = []
	for team_id in participating_team_ids:
		var team_score := int(ctx.state.mode.team_scores.get(team_id, 0))
		if team_score > highest_score:
			highest_score = team_score
			leader_team_ids.clear()
			leader_team_ids.append(team_id)
		elif team_score == highest_score:
			leader_team_ids.append(team_id)

	if leader_team_ids.size() == 1:
		ctx.state.match_state.winner_team_id = int(leader_team_ids[0])
		ctx.state.match_state.winner_player_id = -1
		return

	if _get_score_tiebreak_policy(ctx) == "alive_then_draw":
		var best_alive_count := -1
		var alive_leader_team_ids: Array[int] = []
		for team_id in leader_team_ids:
			var active_count := _count_active_players_for_team(ctx, team_id)
			if active_count > best_alive_count:
				best_alive_count = active_count
				alive_leader_team_ids.clear()
				alive_leader_team_ids.append(team_id)
			elif active_count == best_alive_count:
				alive_leader_team_ids.append(team_id)
		if alive_leader_team_ids.size() == 1:
			ctx.state.match_state.winner_team_id = int(alive_leader_team_ids[0])
			ctx.state.match_state.winner_player_id = -1
			return

	ctx.state.match_state.winner_player_id = -1
	ctx.state.match_state.winner_team_id = -1


func _apply_non_score_time_up_result(ctx: SimContext) -> void:
	var active_team_ids := _collect_active_team_ids(ctx)
	if active_team_ids.size() == 1:
		var winner_team_id := int(active_team_ids[0])
		ctx.state.match_state.winner_team_id = winner_team_id
		ctx.state.match_state.winner_player_id = _resolve_single_active_player_id_for_team(ctx, winner_team_id)
		return

	ctx.state.match_state.winner_player_id = -1
	ctx.state.match_state.winner_team_id = -1


func _collect_participating_team_ids(ctx: SimContext) -> Array[int]:
	var teams: Dictionary = {}
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if player.team_id < 1:
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


func _count_active_players_for_team(ctx: SimContext, team_id: int) -> int:
	var count := 0
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null or player.team_id != team_id:
			continue
		if _is_player_active_for_team_survival(player):
			count += 1
	return count


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


func _can_revive(ctx: SimContext) -> bool:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return bool(rule_flags.get("can_revive", false))
	return false


func _get_score_tiebreak_policy(ctx: SimContext) -> String:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return String(rule_flags.get("score_tiebreak_policy", "draw"))
	return "draw"
