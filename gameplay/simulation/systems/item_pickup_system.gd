class_name ItemPickupSystem
extends ISimSystem

func get_name() -> StringName:
	return "ItemPickupSystem"

func execute(ctx: SimContext) -> void:
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var player_cell_x = player.cell_x
		var player_cell_y = player.cell_y
		var item_id = ctx.queries.get_item_at(player_cell_x, player_cell_y)
		if item_id == -1:
			continue

		var item = ctx.state.items.get_item(item_id)
		if item == null or not item.alive:
			ctx.state.items.active_ids.erase(item_id)
			continue

		if ctx.tick < item.spawn_tick + item.pickup_delay_ticks:
			continue

		item.alive = false
		ctx.state.items.active_ids.erase(item_id)

		match item.item_type:
			1:
				player.bomb_range = min(player.bomb_range + 1, 5)
			2:
				player.bomb_capacity = min(player.bomb_capacity + 1, 5)
				player.bomb_available = min(player.bomb_available + 1, player.bomb_capacity)
			3:
				player.speed_level = min(player.speed_level + 1, 3)
			_:
				pass

		ctx.state.players.update_player(player)

		var item_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_PICKED)
		item_event.payload = {
			"player_id": player_id,
			"item_id": item_id,
			"item_type": item.item_type,
			"cell_x": player_cell_x,
			"cell_y": player_cell_y
		}
		ctx.events.push(item_event)
