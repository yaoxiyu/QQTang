class_name ItemPickupSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")

func get_name() -> StringName:
	return "ItemPickupSystem"

func execute(ctx: SimContext) -> void:
	if _should_suppress_authority_entity_side_effects(ctx):
		return
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var foot_cell := PlayerLocator.get_foot_cell(player)
		var player_cell_x := foot_cell.x
		var player_cell_y := foot_cell.y
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

		_apply_item_effect(ctx, player, item.item_type)

		ctx.state.players.update_player(player)

		var item_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_PICKED)
		item_event.payload = {
			"player_id": player_id,
			"item_id": item_id,
			"item_type": item.item_type,
			"cell_x": foot_cell.x,
			"cell_y": foot_cell.y
		}
		ctx.events.push(item_event)


func _apply_item_effect(ctx: SimContext, player, item_type: int) -> void:
	var item_defs: Dictionary = ctx.config.item_defs
	var item_definition: Dictionary = item_defs.get(item_type, {})
	if not item_definition.is_empty():
		match String(item_definition.get("pickup_effect_type", "")):
			"modify_bomb_range":
				player.bomb_range = min(player.bomb_range + 1, player.max_bomb_range)
			"modify_bomb_capacity":
				player.bomb_capacity = min(player.bomb_capacity + 1, player.max_bomb_capacity)
				player.bomb_available = min(player.bomb_available + 1, player.bomb_capacity)
			"modify_speed":
				player.speed_level = min(player.speed_level + 1, player.max_speed_level)
			"max_bomb_capacity":
				player.bomb_capacity = player.max_bomb_capacity
				player.bomb_available = player.bomb_capacity
			"max_bomb_range":
				player.bomb_range = player.max_bomb_range
			"max_speed":
				player.speed_level = player.max_speed_level
			_:
				_apply_legacy_item_effect(player, item_type)
		return
	_apply_legacy_item_effect(player, item_type)


func _apply_legacy_item_effect(player, item_type: int) -> void:
	match item_type:
		1:
			player.bomb_range = min(player.bomb_range + 1, player.max_bomb_range)
		2:
			player.bomb_capacity = min(player.bomb_capacity + 1, player.max_bomb_capacity)
			player.bomb_available = min(player.bomb_available + 1, player.bomb_capacity)
		3:
			player.speed_level = min(player.speed_level + 1, player.max_speed_level)
		_:
			pass


func _should_suppress_authority_entity_side_effects(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.suppress_authority_entity_side_effects)
