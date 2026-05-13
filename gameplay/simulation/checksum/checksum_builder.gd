class_name ChecksumBuilder
extends RefCounted


func build(sim_world: SimWorld, tick_id: int) -> int:
	var parts := PackedInt64Array()

	parts.append(tick_id)
	parts.append(sim_world.rng.get_state())
	parts.append(sim_world.state.match_state.phase)
	parts.append(sim_world.state.match_state.winner_team_id)
	parts.append(sim_world.state.match_state.winner_player_id)
	parts.append(sim_world.state.match_state.ended_reason)
	parts.append(sim_world.state.match_state.remaining_ticks)

	for player in _get_sorted_players(sim_world):
		parts.append(player.entity_id)
		parts.append(player.cell_x)
		parts.append(player.cell_y)
		parts.append(player.last_non_zero_move_x)
		parts.append(player.last_non_zero_move_y)
		parts.append(player.offset_x)
		parts.append(player.offset_y)
		parts.append(int(player.last_place_bubble_pressed))
		parts.append(player.move_remainder_units)
		parts.append(player.speed_level)
		parts.append(player.max_speed_level)
		parts.append(int(player.alive))
		parts.append(player.life_state)
		parts.append(player.death_display_ticks)
		parts.append(player.trapped_timeout_ticks)
		parts.append(player.bomb_available)
		parts.append(player.bomb_capacity)
		parts.append(player.max_bomb_capacity)
		parts.append(player.bomb_range)
		parts.append(player.max_bomb_range)
		for backpack_id in player.passive_backpack:
			parts.append(hash(backpack_id))
		parts.append(-777777)
		for slot in player.usable_slots:
			if slot is Dictionary:
				parts.append(hash(String(slot.get("battle_item_id", ""))))
				parts.append(int(slot.get("count", 0)))
			else:
				parts.append(0)
				parts.append(0)
		parts.append(-888888)

	for bubble in _get_sorted_bubbles(sim_world):
		parts.append(bubble.entity_id)
		parts.append(bubble.cell_x)
		parts.append(bubble.cell_y)
		parts.append(bubble.explode_tick)
		parts.append(bubble.bubble_range)
		parts.append(bubble.bubble_type)
		parts.append(bubble.power)
		parts.append(bubble.footprint_cells)
		parts.append(int(bubble.alive))
		# pass_phases 必须按 player_id 升序保存（写入路径走 BubblePassPhaseHelper.upsert）。
		for phase in bubble.pass_phases:
			if phase == null:
				continue
			parts.append(phase.player_id)
			parts.append(phase.phase_x)
			parts.append(phase.sign_x)
			parts.append(phase.phase_y)
			parts.append(phase.sign_y)
		parts.append(-999999)

	for item in _get_sorted_items(sim_world):
		parts.append(item.entity_id)
		parts.append(item.cell_x)
		parts.append(item.cell_y)
		parts.append(item.item_type)
		parts.append(hash(item.battle_item_id))
		parts.append(int(item.alive))

	for wall in _get_sorted_walls(sim_world):
		parts.append(int(wall["cell_x"]))
		parts.append(int(wall["cell_y"]))
		parts.append(int(wall["tile_type"]))
		parts.append(int(wall["tile_flags"]))
		parts.append(int(wall["theme_variant"]))

	parts.append(sim_world.state.mode.mode_timer_ticks)
	parts.append(sim_world.state.mode.payload_owner_id)
	parts.append(sim_world.state.mode.payload_cell_x)
	parts.append(sim_world.state.mode.payload_cell_y)
	parts.append(int(sim_world.state.mode.sudden_death_active))

	return _hash_parts(parts)


func _hash_parts(parts: PackedInt64Array) -> int:
	var hash_value: int = 1469598103934665603
	for value in parts:
		hash_value = int((hash_value ^ value) * 1099511628211)
	return hash_value


func _get_sorted_players(sim_world: SimWorld) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for player_id in range(sim_world.state.players.size()):
		var player := sim_world.state.players.get_player(player_id)
		if player != null:
			players.append(player)
	players.sort_custom(func(a: PlayerState, b: PlayerState): return a.entity_id < b.entity_id)
	return players


func _get_sorted_bubbles(sim_world: SimWorld) -> Array[BubbleState]:
	var bubbles: Array[BubbleState] = []
	for bubble_id in sim_world.state.bubbles.active_ids:
		var bubble := sim_world.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			bubbles.append(bubble)
	bubbles.sort_custom(func(a: BubbleState, b: BubbleState): return a.entity_id < b.entity_id)
	return bubbles


func _get_sorted_items(sim_world: SimWorld) -> Array[ItemState]:
	var items: Array[ItemState] = []
	for item_id in sim_world.state.items.active_ids:
		var item := sim_world.state.items.get_item(item_id)
		if item != null:
			items.append(item)
	items.sort_custom(func(a: ItemState, b: ItemState): return a.entity_id < b.entity_id)
	return items


func _get_sorted_walls(sim_world: SimWorld) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	for y in range(sim_world.state.grid.height):
		for x in range(sim_world.state.grid.width):
			var cell = sim_world.state.grid.get_static_cell(x, y)
			walls.append({
				"cell_x": x,
				"cell_y": y,
				"tile_type": cell.tile_type,
				"tile_flags": cell.tile_flags,
				"theme_variant": cell.theme_variant
			})
	return walls
