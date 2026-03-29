class_name ItemSpawnSystem
extends ISimSystem

const DROP_RATE_PROFILES: Array[int] = [25, 50, 75, 100]
static var _drop_rate_profile_index: int = 2


static func cycle_debug_drop_rate_percent() -> int:
	_drop_rate_profile_index = (_drop_rate_profile_index + 1) % DROP_RATE_PROFILES.size()
	return get_debug_drop_rate_percent()


static func get_debug_drop_rate_percent() -> int:
	return DROP_RATE_PROFILES[_drop_rate_profile_index]


func get_name() -> StringName:
	return "ItemSpawnSystem"


func execute(ctx: SimContext) -> void:
	_clear_items_hit_by_explosions(ctx)
	_spawn_items_from_destroyed_cells(ctx)


func _clear_items_hit_by_explosions(ctx: SimContext) -> void:
	for event in ctx.events.get_events():
		if event == null or int(event.event_type) != SimEvent.EventType.BUBBLE_EXPLODED:
			continue

		for cell in event.payload.get("covered_cells", []):
			var item_id: int = _find_item_id_at_cell(ctx, int(cell.x), int(cell.y))
			if item_id == -1:
				continue
			var item: ItemState = ctx.state.items.get_item(item_id)
			if item == null or not item.alive:
				continue
			ctx.state.items.despawn_item(item_id)


func _spawn_items_from_destroyed_cells(ctx: SimContext) -> void:
	for event in ctx.events.get_events():
		if event == null or int(event.event_type) != SimEvent.EventType.CELL_DESTROYED:
			continue

		var cell_x: int = int(event.payload.get("cell_x", -1))
		var cell_y: int = int(event.payload.get("cell_y", -1))
		if cell_x < 0 or cell_y < 0:
			continue
		if not bool(event.payload.get("can_spawn_item", false)):
			continue
		if _find_item_id_at_cell(ctx, cell_x, cell_y) != -1:
			continue

		var item_type: int = _resolve_item_type(cell_x, cell_y)
		if item_type == 0:
			continue

		var item_id: int = ctx.state.items.spawn_item(item_type, cell_x, cell_y, 2)
		var item: ItemState = ctx.state.items.get_item(item_id)
		if item == null:
			continue
		item.spawn_tick = ctx.tick
		item.visible = true
		ctx.state.items.update_item(item)

		var spawned_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_SPAWNED)
		spawned_event.payload = {
			"item_id": item_id,
			"item_type": item_type,
			"cell_x": cell_x,
			"cell_y": cell_y,
			"drop_rate_percent": get_debug_drop_rate_percent(),
		}
		ctx.events.push(spawned_event)


func _find_item_id_at_cell(ctx: SimContext, cell_x: int, cell_y: int) -> int:
	for item_id in ctx.state.items.active_ids:
		var item: ItemState = ctx.state.items.get_item(item_id)
		if item == null or not item.alive:
			continue
		if item.cell_x == cell_x and item.cell_y == cell_y:
			return item_id
	return -1


func _resolve_item_type(cell_x: int, cell_y: int) -> int:
	var drop_selector: int = abs(cell_x * 31 + cell_y * 17) % 100
	if drop_selector >= get_debug_drop_rate_percent():
		return 0

	var type_selector: int = abs(cell_x * 13 + cell_y * 29) % 3
	return type_selector + 1
