class_name ScoreSystem
extends ISimSystem


func get_name() -> StringName:
	return "ScoreSystem"


func execute(ctx: SimContext) -> void:
	if ctx.scratch.score_events.is_empty():
		return

	var score_per_enemy_finish := _get_score_per_enemy_finish(ctx)
	if score_per_enemy_finish <= 0:
		return

	for score_event in ctx.scratch.score_events:
		_apply_score_event(ctx, score_event, score_per_enemy_finish)


func _apply_score_event(ctx: SimContext, score_event: Dictionary, score_delta: int) -> void:
	var victim_player_id := int(score_event.get("victim_player_id", -1))
	var killer_player_id := int(score_event.get("killer_player_id", -1))
	var killer_team_id := int(score_event.get("killer_team_id", -1))
	if victim_player_id < 0 or killer_player_id < 0 or killer_team_id < 1:
		return

	var victim := ctx.state.players.get_player(victim_player_id)
	var killer := ctx.state.players.get_player(killer_player_id)
	if victim == null or killer == null:
		return
	if victim.team_id == killer_team_id or victim.team_id == killer.team_id:
		return

	killer.score += score_delta
	killer.kills += 1
	ctx.state.players.update_player(killer)

	var current_team_score := int(ctx.state.mode.team_scores.get(killer_team_id, 0))
	ctx.state.mode.team_scores[killer_team_id] = current_team_score + score_delta


func _get_score_per_enemy_finish(ctx: SimContext) -> int:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if not (rule_flags is Dictionary):
		return 1
	return max(int(rule_flags.get("score_per_enemy_finish", 1)), 0)
