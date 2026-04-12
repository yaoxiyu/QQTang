class_name DeathPresentationSystem
extends ISimSystem


func get_name() -> StringName:
	return "DeathPresentationSystem"


func execute(ctx: SimContext) -> void:
	if ctx.state.match_state.phase == MatchState.Phase.ENDED:
		return

	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if player.life_state != PlayerState.LifeState.DEAD:
			continue
		if player.death_display_ticks <= 0:
			continue

		player.death_display_ticks -= 1
		ctx.state.players.update_player(player)
