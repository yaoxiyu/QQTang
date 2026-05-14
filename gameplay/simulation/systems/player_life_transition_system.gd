class_name PlayerLifeTransitionSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")


func get_name() -> StringName:
	return "PlayerLifeTransitionSystem"


func execute(ctx: SimContext) -> void:
	_process_players_to_trap(ctx)
	_process_players_to_die(ctx, ctx.scratch.players_to_execute)
	_process_players_to_die(ctx, ctx.scratch.players_to_kill)


func _process_players_to_trap(ctx: SimContext) -> void:
	for player_id in ctx.scratch.players_to_trap:
		var player: PlayerState = ctx.state.players.get_player(player_id)
		if not _can_enter_trapped_state(player):
			continue

		player.life_state = PlayerState.LifeState.TRAPPED
		player.trapped_timeout_ticks = _get_trapped_timeout_ticks(ctx)
		player.move_state = PlayerState.MoveState.IDLE
		player.move_remainder_units = 0
		if player.trap_bubble_id == 0:
			player.trap_bubble_id = -1
		ctx.state.players.update_player(player)
		LogSimulationScript.debug(
			"player_trapped tick=%d player_id=%d source_player_id=%d team_id=%d trap_timeout_ticks=%d cell=(%d,%d)" % [
				ctx.tick,
				player_id,
				player.last_damage_from_player_id,
				player.team_id,
				player.trapped_timeout_ticks,
				player.cell_x,
				player.cell_y,
			],
			"",
			0,
			"sim.life.trapped"
		)

		var foot_cell: Vector2i = PlayerLocator.get_foot_cell(player)
		var trapped_event: SimEvent = SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_TRAPPED)
		trapped_event.payload = {
			"player_id": player_id,
			"source_player_id": player.last_damage_from_player_id,
			"cell_x": foot_cell.x,
			"cell_y": foot_cell.y,
		}
		ctx.events.push(trapped_event)


func _process_players_to_die(ctx: SimContext, player_ids: Array[int]) -> void:
	for player_id in player_ids:
		var player: PlayerState = ctx.state.players.get_player(player_id)
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
	var player_id: int = player.entity_id
	var foot_cell: Vector2i = PlayerLocator.get_foot_cell(player)
	var killer_player_id: int = int(player.last_damage_from_player_id)
	var can_revive: bool = _can_revive(ctx)
	var respawn_ticks: int = _get_respawn_delay_ticks(ctx)
	var death_display_ticks: int = _get_death_display_ticks(ctx)

	player.alive = false
	player.deaths += 1
	player.move_state = PlayerState.MoveState.IDLE
	player.move_remainder_units = 0
	player.trap_bubble_id = -1
	player.trapped_timeout_ticks = 0

	if can_revive and respawn_ticks > 0:
		player.life_state = PlayerState.LifeState.REVIVING
		player.respawn_ticks = respawn_ticks
		player.death_display_ticks = 0
	else:
		player.life_state = PlayerState.LifeState.DEAD
		player.respawn_ticks = 0
		player.death_display_ticks = death_display_ticks

	# 非背包道具拾取后死亡时回收到池
	var pool := ctx.state.item_pool_runtime
	if pool != null:
		for battle_item_id in player.collected_non_backpack_items:
			pool.add_to_recycle(battle_item_id, 1)
	player.collected_non_backpack_items.clear()

	_drop_backpack_on_death(ctx, player, foot_cell)

	ctx.state.players.update_player(player)
	LogSimulationScript.debug(
		"player_finalized_death tick=%d player_id=%d killer_player_id=%d team_id=%d next_life_state=%d respawn_ticks=%d death_display_ticks=%d" % [
			ctx.tick,
			player_id,
			killer_player_id,
			player.team_id,
			player.life_state,
			player.respawn_ticks,
			player.death_display_ticks,
		],
		"",
		0,
		"sim.life.death"
	)
	_remove_player_from_live_indexes(ctx, player_id, foot_cell)
	_remove_player_from_active_ids(ctx, player_id)

	var killed_event: SimEvent = SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_KILLED)
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


func _drop_backpack_on_death(ctx: SimContext, player: PlayerState, foot_cell: Vector2i) -> void:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	if not bool(rule_flags.get("drop_battle_backpack_on_death", false)):
		return

	var drop_items: Array[String] = []
	for battle_item_id in player.passive_backpack.duplicate():
		drop_items.append(battle_item_id)
	player.passive_backpack.clear()

	for i: int in range(6):
		var slot: Variant = player.usable_slots[i]
		if slot is Dictionary:
			for _count in range(int(slot.get("count", 1))):
				drop_items.append(String(slot.get("battle_item_id", "")))
	player.usable_slots = [null, null, null, null, null, null]

	if drop_items.is_empty():
		return

	var scatter_cells: Array[Vector2i] = _collect_scatter_cells(ctx, foot_cell, 3, drop_items.size())
	for i: int in range(drop_items.size()):
		var target_cell: Vector2i = scatter_cells[i % scatter_cells.size()] if not scatter_cells.is_empty() else foot_cell
		_spawn_dropped_item(ctx, target_cell, drop_items[i], foot_cell)


func _spawn_dropped_item(ctx: SimContext, cell: Vector2i, battle_item_id: String, scatter_from: Vector2i) -> void:
	if battle_item_id.is_empty():
		return
	var item_definition: Dictionary = ctx.config.item_defs.get(battle_item_id, {})
	var item_type: int = int(item_definition.get("item_type", 0))
	var item_id: int = ctx.state.items.spawn_item(item_type, cell.x, cell.y, 2, battle_item_id)
	var item: ItemState = ctx.state.items.get_item(item_id)
	if item == null:
		return
	item.spawn_tick = ctx.tick
	item.visible = true
	item.scatter_from_x = scatter_from.x
	item.scatter_from_y = scatter_from.y
	ctx.state.items.update_item(item)

	var spawned_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_SPAWNED)
	spawned_event.payload = {
		"item_id": item_id,
		"item_type": item_type,
		"battle_item_id": battle_item_id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"scatter_from_x": scatter_from.x,
		"scatter_from_y": scatter_from.y,
	}
	ctx.events.push(spawned_event)


func _collect_scatter_cells(ctx: SimContext, center: Vector2i, radius: int, target_count: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cx: int = center.x + dx
			var cy: int = center.y + dy
			if not ctx.state.grid.is_in_bounds(cx, cy):
				continue
			var static_cell: CellStatic = ctx.state.grid.get_static_cell(cx, cy)
			if static_cell.tile_type != TileConstants.TileType.EMPTY:
				continue
			if _is_cell_occupied(ctx, cx, cy):
				continue
			candidates.append(Vector2i(cx, cy))

	if candidates.is_empty():
		return candidates

	_shuffle_array(ctx, candidates)
	var count: int = mini(candidates.size(), target_count)
	var result: Array[Vector2i] = []
	for i: int in range(count):
		result.append(candidates[i])
	return result


func _is_cell_occupied(ctx: SimContext, cx: int, cy: int) -> bool:
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble != null and bubble.alive and bubble.cell_x == cx and bubble.cell_y == cy:
			return true
	for item_id in ctx.state.items.active_ids:
		var item: ItemState = ctx.state.items.get_item(item_id)
		if item != null and item.alive and item.cell_x == cx and item.cell_y == cy:
			return true
	return false


func _shuffle_array(ctx: SimContext, arr: Array) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = ctx.rng.range_int(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _remove_player_from_live_indexes(ctx: SimContext, player_id: int, foot_cell: Vector2i) -> void:
	ctx.state.indexes.living_player_ids.erase(player_id)

	if not ctx.state.grid.is_in_bounds(foot_cell.x, foot_cell.y):
		return

	var cell_idx: int = ctx.state.grid.to_cell_index(foot_cell.x, foot_cell.y)
	if cell_idx < 0 or cell_idx >= ctx.state.indexes.players_by_cell.size():
		return

	var players_in_cell: Array = ctx.state.indexes.players_by_cell[cell_idx]
	var pos: int = players_in_cell.find(player_id)
	if pos != -1:
		players_in_cell.remove_at(pos)


func _remove_player_from_active_ids(ctx: SimContext, player_id: int) -> void:
	var active_pos: int = ctx.state.players.active_ids.find(player_id)
	if active_pos != -1:
		ctx.state.players.active_ids.remove_at(active_pos)


func _can_revive(ctx: SimContext) -> bool:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	return bool(rule_flags.get("can_revive", false))


func _get_respawn_delay_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var respawn_delay_sec: int = int(rule_flags.get("respawn_delay_sec", 0))
	if respawn_delay_sec <= 0:
		return 0
	return respawn_delay_sec * max(ctx.config.tick_rate, 1)


func _get_trapped_timeout_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var trapped_timeout_sec: int = int(rule_flags.get("trapped_timeout_sec", 0))
	if trapped_timeout_sec <= 0:
		return 0
	return trapped_timeout_sec * max(ctx.config.tick_rate, 1)


func _get_death_display_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var death_display_sec: int = int(rule_flags.get("death_display_sec", 2))
	if death_display_sec <= 0:
		return 0
	return death_display_sec * max(ctx.config.tick_rate, 1)


func _get_rule_flags(ctx: SimContext) -> Dictionary:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return rule_flags
	return {}
