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

		var battle_item_id := String(item.battle_item_id)
		if battle_item_id.is_empty():
			_apply_legacy_item_effect(player, item.item_type)
		else:
			if not _try_apply_data_driven_effect(ctx, player, battle_item_id):
				continue

		item.alive = false
		ctx.state.items.active_ids.erase(item_id)
		ctx.state.players.update_player(player)

		var item_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_PICKED)
		item_event.payload = {
			"player_id": player_id,
			"item_id": item_id,
			"item_type": item.item_type,
			"battle_item_id": battle_item_id,
			"cell_x": foot_cell.x,
			"cell_y": foot_cell.y
		}
		ctx.events.push(item_event)


func _try_apply_data_driven_effect(ctx: SimContext, player, battle_item_id: String) -> bool:
	var item_definition: Dictionary = ctx.config.item_defs.get(battle_item_id, {})
	if item_definition.is_empty():
		return false

	var backpack_type := String(item_definition.get("backpack_type", "none"))
	var pool_category := String(item_definition.get("pool_category", ""))
	var apply_on_pickup := bool(item_definition.get("apply_on_pickup", true))

	if apply_on_pickup:
		_execute_effect(ctx, player, item_definition)

	match backpack_type:
		"battle_passive":
			if not player.passive_backpack.has(battle_item_id):
				player.passive_backpack.append(battle_item_id)
		"battle_usable":
			_add_to_usable_slots(player, battle_item_id)
		"permanent":
			pass

	# 不进背包的物品拾取后记录，死亡时回收到池
	if pool_category == "non_backpack":
		if not player.collected_non_backpack_items.has(battle_item_id):
			player.collected_non_backpack_items.append(battle_item_id)

	return true


func _add_to_usable_slots(player, battle_item_id: String) -> void:
	for i in range(6):
		var slot = player.usable_slots[i]
		if slot is Dictionary and String(slot.get("battle_item_id", "")) == battle_item_id:
			slot["count"] = int(slot.get("count", 0)) + 1
			return

	for i in range(6):
		if player.usable_slots[i] == null:
			player.usable_slots[i] = {"battle_item_id": battle_item_id, "count": 1}
			return


func _execute_effect(ctx: SimContext, player, item_definition: Dictionary) -> void:
	var effect_type := String(item_definition.get("effect_type", ""))
	var effect_target := String(item_definition.get("effect_target", ""))
	var effect_mode := String(item_definition.get("effect_mode", ""))
	var effect_value := int(item_definition.get("effect_value", 0))

	match effect_type:
		"stat_mod":
			_apply_stat_mod(player, effect_target, effect_mode, effect_value)
		"transform":
			pass
		"grant_player_item":
			pass


func _apply_stat_mod(player, target: String, mode: String, value: int) -> void:
	if target.is_empty():
		return

	var max_key := "max_" + target
	var max_val: int = player.get(max_key) if max_key in player else 0

	match mode:
		"add":
			var current: int = player.get(target) if target in player else 0
			player.set(target, min(current + value, max_val))
			if target == "bomb_capacity":
				player.bomb_available = min(player.bomb_available + value, max_val)
		"set":
			player.set(target, value)
			if target == "bomb_capacity":
				player.bomb_available = min(player.bomb_available, value)
		"set_max":
			player.set(target, max_val)
			if target == "bomb_capacity":
				player.bomb_available = max_val


func _apply_legacy_item_effect(player, item_type: int) -> void:
	match item_type:
		1:
			player.bomb_range = min(player.bomb_range + 1, player.max_bomb_range)
		2:
			player.bomb_capacity = min(player.bomb_capacity + 1, player.max_bomb_capacity)
			player.bomb_available = min(player.bomb_available + 1, player.bomb_capacity)
		3:
			player.speed_level = min(player.speed_level + 1, player.max_speed_level)


func _should_suppress_authority_entity_side_effects(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.suppress_authority_entity_side_effects)
