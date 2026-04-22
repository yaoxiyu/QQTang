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
	if _should_suppress_authority_entity_side_effects(ctx):
		return
	_spawn_items_from_destroyed_cells(ctx)


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

		var item_type: int = _resolve_item_type(ctx)
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


func _resolve_item_type(ctx: SimContext) -> int:
	if ctx == null or ctx.config == null:
		return _resolve_legacy_debug_item_type(ctx)
	var item_drop_profile: Dictionary = ctx.config.system_flags.get("item_drop_profile", {})
	if not item_drop_profile.is_empty():
		return _roll_item_type_from_profile(ctx, item_drop_profile)
	return _resolve_legacy_debug_item_type(ctx)


func _roll_item_type_from_profile(ctx: SimContext, item_drop_profile: Dictionary) -> int:
	if not bool(item_drop_profile.get("drop_enabled", true)):
		return 0
	var total_weight: int = max(int(item_drop_profile.get("empty_weight", 0)), 0)
	for entry in item_drop_profile.get("drop_pool", []):
		total_weight += max(int(entry.get("weight", 0)), 0)
	if total_weight <= 0:
		return 0
	var roll: int = int(ctx.rng.range_int(0, total_weight - 1))
	var cursor: int = max(int(item_drop_profile.get("empty_weight", 0)), 0)
	if roll < cursor:
		return 0
	for entry in item_drop_profile.get("drop_pool", []):
		cursor += max(int(entry.get("weight", 0)), 0)
		if roll < cursor:
			return int(entry.get("item_type", 0))
	return 0


func _resolve_legacy_debug_item_type(ctx: SimContext) -> int:
	if ctx == null or ctx.rng == null:
		return 0
	var drop_selector: int = ctx.rng.range_int(0, 99)
	if drop_selector >= get_debug_drop_rate_percent():
		return 0
	return ctx.rng.range_int(1, 3)


func _should_suppress_authority_entity_side_effects(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.suppress_authority_entity_side_effects)
