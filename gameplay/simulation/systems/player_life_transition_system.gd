class_name PlayerLifeTransitionSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")


func get_name() -> StringName:
	return "PlayerLifeTransitionSystem"


func execute(ctx: SimContext) -> void:
	_process_players_to_trap(ctx)
	_process_players_to_die(ctx, ctx.scratch.players_to_execute)
	_process_players_to_die(ctx, ctx.scratch.players_to_kill)


func _process_players_to_trap(ctx: SimContext) -> void:
	for player_id in ctx.scratch.players_to_trap:
		var player := ctx.state.players.get_player(player_id)
		if not _can_enter_trapped_state(player):
			continue

		player.life_state = PlayerState.LifeState.TRAPPED
		player.move_state = PlayerState.MoveState.IDLE
		player.offset_x = 0
		player.offset_y = 0
		player.move_phase_ticks = 0
		if player.trap_bubble_id == 0:
			player.trap_bubble_id = -1
		ctx.state.players.update_player(player)

		var foot_cell := PlayerLocator.get_foot_cell(player)
		var trapped_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_TRAPPED)
		trapped_event.payload = {
			"player_id": player_id,
			"source_player_id": player.last_damage_from_player_id,
			"cell_x": foot_cell.x,
			"cell_y": foot_cell.y,
		}
		ctx.events.push(trapped_event)


func _process_players_to_die(ctx: SimContext, player_ids: Array[int]) -> void:
	for player_id in player_ids:
		var player := ctx.state.players.get_player(player_id)
		if not _can_finalize_death(player):
			continue
		_finalize_player_death(ctx, player)


func _can_enter_trapped_state(player: PlayerState) -> bool:
	if player == null:
		return false
	if not player.alive:
		return false
	if player.invincible_ticks > 0:
		return false
	return player.life_state == PlayerState.LifeState.NORMAL


func _can_finalize_death(player: PlayerState) -> bool:
	if player == null:
		return false
	if not player.alive:
		return false
	if player.invincible_ticks > 0:
		return false
	return player.life_state != PlayerState.LifeState.DEAD and player.life_state != PlayerState.LifeState.REVIVING


func _finalize_player_death(ctx: SimContext, player: PlayerState) -> void:
	var player_id := player.entity_id
	var foot_cell := PlayerLocator.get_foot_cell(player)
	var killer_player_id := int(player.last_damage_from_player_id)
	var respawn_enabled := _is_respawn_enabled(ctx)
	var respawn_ticks := _get_respawn_delay_ticks(ctx)

	player.alive = false
	player.deaths += 1
	player.move_state = PlayerState.MoveState.IDLE
	player.offset_x = 0
	player.offset_y = 0
	player.move_phase_ticks = 0
	player.trap_bubble_id = -1

	if respawn_enabled and respawn_ticks > 0:
		player.life_state = PlayerState.LifeState.REVIVING
		player.respawn_ticks = respawn_ticks
	else:
		player.life_state = PlayerState.LifeState.DEAD
		player.respawn_ticks = 0

	ctx.state.players.update_player(player)
	_remove_player_from_live_indexes(ctx, player_id, foot_cell)
	_remove_player_from_active_ids(ctx, player_id)

	var killed_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_KILLED)
	killed_event.payload = {
		"victim_player_id": player_id,
		"killer_player_id": killer_player_id,
		"cell_x": foot_cell.x,
		"cell_y": foot_cell.y,
		"life_state": player.life_state,
	}
	ctx.events.push(killed_event)

	if killer_player_id > 0:
		var killer := ctx.state.players.get_player(killer_player_id)
		var killer_team_id := -1
		if killer != null:
			killer_team_id = killer.team_id
		ctx.scratch.score_events.append({
			"victim_player_id": player_id,
			"killer_player_id": killer_player_id,
			"killer_team_id": killer_team_id,
		})


func _remove_player_from_live_indexes(ctx: SimContext, player_id: int, foot_cell: Vector2i) -> void:
	ctx.state.indexes.living_player_ids.erase(player_id)

	if not ctx.state.grid.is_in_bounds(foot_cell.x, foot_cell.y):
		return

	var cell_idx := ctx.state.grid.to_cell_index(foot_cell.x, foot_cell.y)
	if cell_idx < 0 or cell_idx >= ctx.state.indexes.players_by_cell.size():
		return

	var players_in_cell: Array = ctx.state.indexes.players_by_cell[cell_idx]
	var pos := players_in_cell.find(player_id)
	if pos != -1:
		players_in_cell.remove_at(pos)


func _remove_player_from_active_ids(ctx: SimContext, player_id: int) -> void:
	var active_pos := ctx.state.players.active_ids.find(player_id)
	if active_pos != -1:
		ctx.state.players.active_ids.remove_at(active_pos)


func _is_respawn_enabled(ctx: SimContext) -> bool:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	return bool(rule_flags.get("respawn_enabled", false))


func _get_respawn_delay_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var respawn_delay_sec := int(rule_flags.get("respawn_delay_sec", 0))
	if respawn_delay_sec <= 0:
		return 0
	return respawn_delay_sec * max(ctx.config.tick_rate, 1)


func _get_rule_flags(ctx: SimContext) -> Dictionary:
	var rule_flags := ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return rule_flags
	return {}
