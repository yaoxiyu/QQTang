class_name Phase2ItemDropBridge
extends RefCounted

var last_processed_tick: int = -1


func reset() -> void:
	last_processed_tick = -1


func process_tick(world: SimWorld) -> void:
	if world == null:
		return
	var tick_id := int(world.state.match_state.tick)
	if tick_id == last_processed_tick:
		return

	var items_changed := _clear_items_hit_by_explosions(world)
	var spawned_any := false
	for event in world.events.get_events():
		if event == null or int(event.event_type) != SimEvent.EventType.CELL_DESTROYED:
			continue

		var cell_x := int(event.payload.get("cell_x", -1))
		var cell_y := int(event.payload.get("cell_y", -1))
		if cell_x < 0 or cell_y < 0:
			continue
		if world.queries.get_item_at(cell_x, cell_y) != -1:
			continue

		var item_type := _resolve_item_type(cell_x, cell_y)
		if item_type == 0:
			continue

		var item_id := world.state.items.spawn_item(item_type, cell_x, cell_y, 2)
		var item := world.state.items.get_item(item_id)
		if item == null:
			continue
		item.spawn_tick = tick_id
		item.visible = true
		world.state.items.update_item(item)

		var spawned_event := SimEvent.new(tick_id, SimEvent.EventType.ITEM_SPAWNED)
		spawned_event.payload = {
			"item_id": item_id,
			"item_type": item_type,
			"cell_x": cell_x,
			"cell_y": cell_y
		}
		world.events.push(spawned_event)
		spawned_any = true

	if items_changed or spawned_any:
		world.rebuild_runtime_indexes()

	last_processed_tick = tick_id


func _clear_items_hit_by_explosions(world: SimWorld) -> bool:
	var changed := false
	for event in world.events.get_events():
		if event == null or int(event.event_type) != SimEvent.EventType.BUBBLE_EXPLODED:
			continue

		for cell in event.payload.get("covered_cells", []):
			var item_id := world.queries.get_item_at(cell.x, cell.y)
			if item_id == -1:
				continue
			var item := world.state.items.get_item(item_id)
			if item == null or not item.alive:
				continue
			world.state.items.despawn_item(item_id)
			changed = true

	return changed


func _resolve_item_type(cell_x: int, cell_y: int) -> int:
	var selector: int = abs(cell_x * 31 + cell_y * 17) % 4
	match selector:
		0:
			return 1
		1:
			return 2
		2:
			return 3
		_:
			return 0
