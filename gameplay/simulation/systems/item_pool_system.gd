class_name ItemPoolSystem
extends ISimSystem

const TileConstantsScript = preload("res://gameplay/simulation/state/tile_constants.gd")

const MAX_DROP_COUNT := 3
const AIRPLANE_SPEED := 0.16  # cells/tick, 跨屏约 3 秒+
const AIRPLANE_DROP_POINTS := 3
const AIRDROP_ARC_HEIGHT_CELLS := 1.5
const AIRDROP_ITEM_SPEED_CELLS_PER_TICK := 0.12
const AIRDROP_ARC_LENGTH_SAMPLES := 20


func get_name() -> StringName:
	return "ItemPoolSystem"


func execute(ctx: SimContext) -> void:
	if _should_defer_client_predicted_airdrop(ctx):
		return
	if _should_suppress_authority_entity_side_effects(ctx):
		return
	var pool := ctx.state.item_pool_runtime
	if pool == null:
		return
	_ensure_drop_cell_cache_initialized(ctx, pool)
	_sync_drop_cell_cache_from_destroyed_cells(ctx, pool)

	# 处理飞行中的飞机
	if pool.airplane_active:
		_tick_airplane(ctx, pool)
		return

	# 计时器倒计时
	if pool.airplane_timer_ticks > 0:
		pool.airplane_timer_ticks -= 1
		if pool.airplane_timer_ticks <= 0:
			_spawn_airplane(ctx, pool)


func _spawn_airplane(ctx: SimContext, pool) -> void:
	# 回收池无物品时不触发飞机
	if pool.recycle_pool.is_empty():
		pool.airplane_timer_ticks = pool.airplane_interval_ticks
		return

	pool.airplane_active = true
	pool.airplane_x = float(ctx.state.grid.width)  # 从右边缘外进入
	pool.airplane_y = _pick_airplane_row(ctx)
	pool.airplane_drop_cooldown = 0
	pool.airplane_drop_plan_total = mini(AIRPLANE_DROP_POINTS, _recycle_total_count(pool))
	pool.airplane_drop_plan_done = 0

	var spawn_event := SimEvent.new(ctx.tick, SimEvent.EventType.AIRPLANE_SPAWNED)
	spawn_event.payload = {
		"airplane_y": pool.airplane_y,
		"grid_width": ctx.state.grid.width,
	}
	ctx.events.push(spawn_event)


func _tick_airplane(ctx: SimContext, pool) -> void:
	pool.airplane_x -= AIRPLANE_SPEED

	# 退出左边界 → 飞机离开
	if pool.airplane_x < -1.0:
		_despawn_airplane(ctx, pool)
		return

	_try_progressive_drops(ctx, pool)


func _despawn_airplane(_ctx: SimContext, pool) -> void:
	pool.airplane_active = false
	pool.airplane_x = 0.0
	pool.airplane_drop_plan_total = 0
	pool.airplane_drop_plan_done = 0
	pool.airplane_timer_ticks = pool.airplane_interval_ticks


func _spawn_dropped_item(ctx: SimContext, pool, cell: Vector2i, battle_item_id: String) -> void:
	var item_definition: Dictionary = ctx.config.item_defs.get(battle_item_id, {})
	if item_definition.is_empty():
		return
	var item_type: int = int(item_definition.get("item_type", 0))
	var pool_category: String = String(item_definition.get("pool_category", ""))
	var scatter_from_cell_world := Vector2(float(pool.airplane_x) + 0.5, float(pool.airplane_y) + 0.5)
	var target_cell_world := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	var pickup_delay_ticks := _compute_airdrop_pickup_delay_ticks(scatter_from_cell_world, target_cell_world)
	var item_id: int = ctx.state.items.spawn_item(item_type, cell.x, cell.y, pickup_delay_ticks, battle_item_id, pool_category)
	var item: ItemState = ctx.state.items.get_item(item_id)
	if item == null:
		return
	item.spawn_tick = ctx.tick
	item.visible = true
	# 设置散落起点为飞机当前位置，复用死亡掉落轨迹动画
	item.scatter_from_x = int(floorf(scatter_from_cell_world.x))
	item.scatter_from_y = pool.airplane_y
	item.scatter_from_world_x = scatter_from_cell_world.x
	item.scatter_from_world_y = scatter_from_cell_world.y
	ctx.state.items.update_item(item)

	var spawned_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_AIRPLANE_DROPPED)
	spawned_event.payload = {
		"item_id": item_id,
		"item_type": item_type,
		"battle_item_id": battle_item_id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"scatter_from_x": int(floorf(scatter_from_cell_world.x)),
		"scatter_from_y": pool.airplane_y,
		"scatter_from_world_x": scatter_from_cell_world.x,
		"scatter_from_world_y": scatter_from_cell_world.y,
		"pickup_delay_ticks": pickup_delay_ticks,
	}
	ctx.events.push(spawned_event)


func _pick_airplane_row(ctx: SimContext) -> int:
	# 固定从右侧中线飞入，保证视觉一致性与可预期性。
	var h := maxi(1, int(ctx.state.grid.height))
	return clampi(int(h / 2), 0, h - 1)


func _try_progressive_drops(ctx: SimContext, pool) -> void:
	var total: int = int(pool.airplane_drop_plan_total)
	if total <= 0:
		return
	while int(pool.airplane_drop_plan_done) < total:
		var next_index := int(pool.airplane_drop_plan_done) + 1
		var threshold := float(next_index) / float(total + 1)
		if _airplane_flight_progress(ctx, pool) + 0.00001 < threshold:
			return
		if not _try_single_drop(ctx, pool):
			return
		pool.airplane_drop_plan_done = next_index


func _try_single_drop(ctx: SimContext, pool) -> bool:
	var drop_cell := _find_drop_cell(ctx, pool)
	if drop_cell.x < 0:
		return false  # 无可用落点，本 tick 放弃

	var drop_ids: Array[String] = pool.consume_from_recycle(1)
	if drop_ids.is_empty():
		return false

	_spawn_dropped_item(ctx, pool, drop_cell, drop_ids[0])
	return true


func _airplane_flight_progress(ctx: SimContext, pool) -> float:
	var start_x := float(ctx.state.grid.width)
	var end_x := -1.0
	var distance := maxf(start_x - end_x, 1.0)
	var traveled := start_x - float(pool.airplane_x)
	return clampf(traveled / distance, 0.0, 1.0)


func _recycle_total_count(pool) -> int:
	var total := 0
	for bid in pool.recycle_pool.keys():
		total += maxi(0, int(pool.recycle_pool.get(bid, 0)))
	return total


func _find_drop_cell(ctx: SimContext, pool) -> Vector2i:
	# 全图缓存中随机；角色/泡泡/道具占位允许（豁免），只校验地形与禁投覆盖层。
	while not pool.cached_drop_cells.is_empty():
		var idx := 0
		if ctx != null and ctx.rng != null:
			idx = int(ctx.rng.range_int(0, pool.cached_drop_cells.size()))
		var candidate := pool.cached_drop_cells[idx] as Vector2i
		if _is_drop_cell_valid(ctx, pool, candidate.x, candidate.y):
			return candidate
		_remove_cached_drop_cell(pool, idx)
	return Vector2i(-1, -1)


func _is_drop_blocked(pool, cell_x: int, cell_y: int) -> bool:
	return pool.blocked_drop_cells.has("%d,%d" % [cell_x, cell_y])


func _is_drop_cell_valid(ctx: SimContext, pool, cell_x: int, cell_y: int) -> bool:
	var grid := ctx.state.grid
	if grid == null or not grid.is_in_bounds(cell_x, cell_y):
		return false
	if grid.get_static_cell(cell_x, cell_y).tile_type != TileConstantsScript.TileType.EMPTY:
		return false
	if _is_drop_blocked(pool, cell_x, cell_y):
		return false
	return true


func _ensure_drop_cell_cache_initialized(ctx: SimContext, pool) -> void:
	if not pool.cached_drop_cells.is_empty() or not pool.cached_drop_index_by_key.is_empty():
		return
	var grid := ctx.state.grid
	if grid == null:
		return
	for y in range(grid.height):
		for x in range(grid.width):
			if _is_drop_cell_valid(ctx, pool, x, y):
				_add_cached_drop_cell(pool, Vector2i(x, y))


func _sync_drop_cell_cache_from_destroyed_cells(ctx: SimContext, pool) -> void:
	if ctx == null or ctx.events == null:
		return
	for event in ctx.events.events:
		if event == null or int(event.event_type) != SimEvent.EventType.CELL_DESTROYED:
			continue
		var cell_x := int(event.payload.get("cell_x", -1))
		var cell_y := int(event.payload.get("cell_y", -1))
		if cell_x < 0 or cell_y < 0:
			continue
		_refresh_cached_drop_cell(ctx, pool, cell_x, cell_y)


func _refresh_cached_drop_cell(ctx: SimContext, pool, cell_x: int, cell_y: int) -> void:
	var key := "%d,%d" % [cell_x, cell_y]
	if _is_drop_cell_valid(ctx, pool, cell_x, cell_y):
		if not pool.cached_drop_index_by_key.has(key):
			_add_cached_drop_cell(pool, Vector2i(cell_x, cell_y))
		return
	if not pool.cached_drop_index_by_key.has(key):
		return
	_remove_cached_drop_cell(pool, int(pool.cached_drop_index_by_key[key]))


func _add_cached_drop_cell(pool, cell: Vector2i) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	if pool.cached_drop_index_by_key.has(key):
		return
	pool.cached_drop_index_by_key[key] = pool.cached_drop_cells.size()
	pool.cached_drop_cells.append(cell)


func _remove_cached_drop_cell(pool, index: int) -> void:
	if index < 0 or index >= pool.cached_drop_cells.size():
		return
	var last_idx: int = pool.cached_drop_cells.size() - 1
	var removed_cell := pool.cached_drop_cells[index] as Vector2i
	var removed_key := "%d,%d" % [removed_cell.x, removed_cell.y]
	if index != last_idx:
		var last_cell := pool.cached_drop_cells[last_idx] as Vector2i
		pool.cached_drop_cells[index] = last_cell
		pool.cached_drop_index_by_key["%d,%d" % [last_cell.x, last_cell.y]] = index
	pool.cached_drop_cells.remove_at(last_idx)
	pool.cached_drop_index_by_key.erase(removed_key)


func _compute_airdrop_pickup_delay_ticks(from_cell_world: Vector2, to_cell_world: Vector2) -> int:
	var path_length_cells := _estimate_parabola_path_length_cells(from_cell_world, to_cell_world)
	var raw_ticks := path_length_cells / maxf(AIRDROP_ITEM_SPEED_CELLS_PER_TICK, 0.001)
	return maxi(1, int(ceil(raw_ticks)))


func _estimate_parabola_path_length_cells(from_cell_world: Vector2, to_cell_world: Vector2) -> float:
	var mid := (from_cell_world + to_cell_world) * 0.5
	mid.y -= AIRDROP_ARC_HEIGHT_CELLS
	var total := 0.0
	var prev := from_cell_world
	for i in range(1, AIRDROP_ARC_LENGTH_SAMPLES + 1):
		var t := float(i) / float(AIRDROP_ARC_LENGTH_SAMPLES)
		var point := _quadratic_bezier_point(from_cell_world, mid, to_cell_world, t)
		total += prev.distance_to(point)
		prev = point
	return maxf(total, from_cell_world.distance_to(to_cell_world))


func _quadratic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func debug_rebuild_drop_cell_cache(ctx: SimContext, pool) -> void:
	pool.cached_drop_cells.clear()
	pool.cached_drop_index_by_key.clear()
	_ensure_drop_cell_cache_initialized(ctx, pool)


func debug_drop_cell_cache_size(pool) -> int:
	return pool.cached_drop_cells.size()


func debug_is_cell_cached(pool, cell_x: int, cell_y: int) -> bool:
	return pool.cached_drop_index_by_key.has("%d,%d" % [cell_x, cell_y])


func _should_suppress_authority_entity_side_effects(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.suppress_authority_entity_side_effects)


func _should_defer_client_predicted_airdrop(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.client_prediction_mode)
