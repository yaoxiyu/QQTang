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

	var alive_players: Array[int] = ctx.state.indexes.living_player_ids.duplicate()
	alive_players.sort()
	if alive_players.size() == 1:
		var winner_id := int(alive_players[0])
		var winner := ctx.queries.get_player(winner_id)
		ctx.state.match_state.winner_player_id = winner_id
		ctx.state.match_state.winner_team_id = winner.team_id if winner != null else -1
	else:
		ctx.state.match_state.winner_player_id = -1
		ctx.state.match_state.winner_team_id = -1

	var match_end_event := SimEvent.new(ctx.tick, SimEvent.EventType.MATCH_ENDED)
	match_end_event.payload = {
		"winner_player_id": ctx.state.match_state.winner_player_id,
		"winner_team_id": ctx.state.match_state.winner_team_id,
		"reason": ctx.state.match_state.ended_reason,
	}
	ctx.events.push(match_end_event)