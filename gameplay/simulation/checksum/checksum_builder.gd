class_name ChecksumBuilder
extends RefCounted


func build(sim_world: SimWorld, tick_id: int) -> int:
	var parts := PackedInt64Array()

	parts.append(tick_id)
	parts.append(sim_world.rng.get_state())

	for player in _get_sorted_players(sim_world):
		parts.append(player.entity_id)
		parts.append(player.cell_x)
		parts.append(player.cell_y)
		parts.append(player.last_non_zero_move_x)
		parts.append(player.last_non_zero_move_y)
		parts.append(player.offset_x)
		parts.append(player.offset_y)
		parts.append(int(player.alive))
		parts.append(player.life_state)
		parts.append(player.bomb_available)
		parts.append(player.bomb_range)

	for bubble in _get_sorted_bubbles(sim_world):
		parts.append(bubble.entity_id)
		parts.append(bubble.cell_x)
		parts.append(bubble.cell_y)
		parts.append(bubble.explode_tick)
		parts.append(bubble.bubble_range)
		parts.append(int(bubble.alive))

	for item in _get_sorted_items(sim_world):
		parts.append(item.entity_id)
		parts.append(item.cell_x)
		parts.append(item.cell_y)
		parts.append(item.item_type)
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
	for player_id in sim_world.state.players.active_ids:
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
