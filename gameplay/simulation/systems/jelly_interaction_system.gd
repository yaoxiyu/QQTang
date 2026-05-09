class_name JellyInteractionSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")

const CELL_UNITS := 1000


func get_name() -> StringName:
	return "JellyInteractionSystem"


func execute(ctx: SimContext) -> void:
	var trapped_players := _collect_trapped_players(ctx)
	if trapped_players.is_empty():
		return

	var normal_players := _collect_normal_players(ctx)

	for trapped_player in trapped_players:
		if trapped_player == null or trapped_player.life_state != PlayerState.LifeState.TRAPPED:
			continue
		var touched := false

		for actor_player in normal_players:
			if actor_player == null:
				continue
			if actor_player.entity_id == trapped_player.entity_id:
				continue
			if not _is_touching(trapped_player, actor_player):
				continue
			touched = true

			if trapped_player.team_id == actor_player.team_id:
				if _is_rescue_enabled(ctx):
					_rescue_player(ctx, trapped_player, actor_player)
					break
			elif _is_enemy_execute_enabled(ctx):
				_execute_player(ctx, trapped_player, actor_player)
				break
		if trapped_player.life_state == PlayerState.LifeState.TRAPPED:
			_tick_trapped_timeout(ctx, trapped_player, touched)


func _collect_trapped_players(ctx: SimContext) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for player_id in ctx.state.players.active_ids:
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if not player.alive:
			continue
		if player.life_state != PlayerState.LifeState.TRAPPED:
			continue
		players.append(player)
	return players


func _collect_normal_players(ctx: SimContext) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for player_id in ctx.state.players.active_ids:
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if not player.alive:
			continue
		if player.life_state != PlayerState.LifeState.NORMAL:
			continue
		players.append(player)
	return players


func _is_touching(trapped_player: PlayerState, actor_player: PlayerState) -> bool:
	var trapped_abs := PlayerLocator.get_abs_pos(trapped_player)
	var actor_abs := PlayerLocator.get_abs_pos(actor_player)
	var dx := absi(trapped_abs.x - actor_abs.x)
	var dy := absi(trapped_abs.y - actor_abs.y)
	return (dx <= CELL_UNITS and dy < CELL_UNITS) or (dy <= CELL_UNITS and dx < CELL_UNITS)


func _rescue_player(ctx: SimContext, trapped_player: PlayerState, rescuer_player: PlayerState) -> void:
	trapped_player.life_state = PlayerState.LifeState.NORMAL
	trapped_player.trap_bubble_id = -1
	trapped_player.trapped_timeout_ticks = 0
	trapped_player.last_damage_from_player_id = -1
	trapped_player.invincible_ticks = _get_rescue_invincible_ticks(ctx)
	trapped_player.move_state = PlayerState.MoveState.IDLE
	trapped_player.move_remainder_units = 0
	ctx.state.players.update_player(trapped_player)
	LogSimulationScript.debug(
		"jelly_rescue tick=%d trapped_player_id=%d rescuer_player_id=%d team_id=%d invincible_ticks=%d" % [
			ctx.tick,
			trapped_player.entity_id,
			rescuer_player.entity_id,
			trapped_player.team_id,
			trapped_player.invincible_ticks,
		],
		"",
		0,
		"sim.jelly.rescue"
	)

	var foot_cell := PlayerLocator.get_foot_cell(trapped_player)
	var revived_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_REVIVED)
	revived_event.payload = {
		"player_id": trapped_player.entity_id,
		"rescuer_player_id": rescuer_player.entity_id,
		"cell_x": foot_cell.x,
		"cell_y": foot_cell.y,
	}
	ctx.events.push(revived_event)


func _execute_player(ctx: SimContext, trapped_player: PlayerState, finisher_player: PlayerState) -> void:
	trapped_player.last_damage_from_player_id = finisher_player.entity_id
	ctx.state.players.update_player(trapped_player)
	LogSimulationScript.debug(
		"jelly_execute tick=%d trapped_player_id=%d finisher_player_id=%d trapped_team_id=%d finisher_team_id=%d trap_timeout_ticks=%d" % [
			ctx.tick,
			trapped_player.entity_id,
			finisher_player.entity_id,
			trapped_player.team_id,
			finisher_player.team_id,
			trapped_player.trapped_timeout_ticks,
		],
		"",
		0,
		"sim.jelly.execute"
	)
	if not ctx.scratch.players_to_execute.has(trapped_player.entity_id):
		ctx.scratch.players_to_execute.append(trapped_player.entity_id)
	var foot_cell := PlayerLocator.get_foot_cell(trapped_player)
	var executed_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_TRAP_EXECUTED)
	executed_event.payload = {
		"player_id": trapped_player.entity_id,
		"finisher_player_id": finisher_player.entity_id,
		"cell_x": foot_cell.x,
		"cell_y": foot_cell.y,
	}
	ctx.events.push(executed_event)


func _tick_trapped_timeout(ctx: SimContext, trapped_player: PlayerState, touched: bool) -> void:
	if touched:
		LogSimulationScript.debug(
			"jelly_timeout_paused tick=%d trapped_player_id=%d remaining_ticks=%d reason=touched" % [
				ctx.tick,
				trapped_player.entity_id,
				trapped_player.trapped_timeout_ticks,
			],
			"",
			0,
			"sim.jelly.timeout"
		)
		return
	if trapped_player.trapped_timeout_ticks <= 0:
		LogSimulationScript.debug(
			"jelly_timeout_disabled tick=%d trapped_player_id=%d remaining_ticks=%d" % [
				ctx.tick,
				trapped_player.entity_id,
				trapped_player.trapped_timeout_ticks,
			],
			"",
			0,
			"sim.jelly.timeout"
		)
		return
	trapped_player.trapped_timeout_ticks -= 1
	LogSimulationScript.debug(
		"jelly_timeout_tick tick=%d trapped_player_id=%d remaining_ticks=%d" % [
			ctx.tick,
			trapped_player.entity_id,
			trapped_player.trapped_timeout_ticks,
		],
		"",
		0,
		"sim.jelly.timeout"
	)
	if trapped_player.trapped_timeout_ticks <= 0:
		trapped_player.last_damage_from_player_id = -1
		LogSimulationScript.info(
			"jelly_timeout_execute tick=%d trapped_player_id=%d" % [
				ctx.tick,
				trapped_player.entity_id,
			],
			"",
			0,
			"sim.jelly.timeout"
		)
		if not ctx.scratch.players_to_execute.has(trapped_player.entity_id):
			ctx.scratch.players_to_execute.append(trapped_player.entity_id)
	ctx.state.players.update_player(trapped_player)


func _is_rescue_enabled(ctx: SimContext) -> bool:
	return bool(_get_rule_flags(ctx).get("rescue_touch_enabled", false))


func _is_enemy_execute_enabled(ctx: SimContext) -> bool:
	return bool(_get_rule_flags(ctx).get("enemy_touch_execute_enabled", false))


func _get_rescue_invincible_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var invincible_sec := int(rule_flags.get("respawn_invincible_sec", 0))
	if invincible_sec <= 0:
		return 0
	return invincible_sec * max(ctx.config.tick_rate, 1)


func _get_rule_flags(ctx: SimContext) -> Dictionary:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return rule_flags
	return {}
