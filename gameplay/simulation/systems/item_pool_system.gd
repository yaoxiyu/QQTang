class_name ItemPoolSystem
extends ISimSystem

const TileConstantsScript = preload("res://gameplay/simulation/state/tile_constants.gd")

const MAX_DROP_COUNT := 3
const AIRPLANE_SPEED := 0.27  # cells/tick, 跨屏约 2 秒
const DROP_INTERVAL_TICKS := 30  # 飞行中每 1s 空投一次


func get_name() -> StringName:
	return "ItemPoolSystem"


func execute(ctx: SimContext) -> void:
	if _should_suppress_authority_entity_side_effects(ctx):
		return
	var pool := ctx.state.item_pool_runtime
	if pool == null:
		return

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
	pool.airplane_drop_cooldown = maxi(5, int(DROP_INTERVAL_TICKS / 2))  # 首次空投延迟减半

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

	# 空投冷却
	pool.airplane_drop_cooldown -= 1
	if pool.airplane_drop_cooldown > 0:
		return

	# 空投一个道具
	var drop_ids: Array[String] = pool.consume_from_recycle(1)
	if drop_ids.is_empty():
		return
	pool.airplane_drop_cooldown = DROP_INTERVAL_TICKS

	var drop_cell := _find_drop_cell(ctx, pool)
	if drop_cell.x < 0:
		return  # 无可用落点，跳过

	var battle_item_id := drop_ids[0]
	_spawn_dropped_item(ctx, pool, drop_cell, battle_item_id)


func _despawn_airplane(_ctx: SimContext, pool) -> void:
	pool.airplane_active = false
	pool.airplane_x = 0.0
	pool.airplane_timer_ticks = pool.airplane_interval_ticks


func _spawn_dropped_item(ctx: SimContext, pool, cell: Vector2i, battle_item_id: String) -> void:
	var item_definition: Dictionary = ctx.config.item_defs.get(battle_item_id, {})
	if item_definition.is_empty():
		return
	var item_type: int = int(item_definition.get("item_type", 0))
	var pool_category: String = String(item_definition.get("pool_category", ""))
	var item_id: int = ctx.state.items.spawn_item(item_type, cell.x, cell.y, 2, battle_item_id, pool_category)
	var item: ItemState = ctx.state.items.get_item(item_id)
	if item == null:
		return
	item.spawn_tick = ctx.tick
	item.visible = true
	# 设置散落起点为飞机当前位置，复用死亡掉落轨迹动画
	item.scatter_from_x = int(pool.airplane_x)
	item.scatter_from_y = pool.airplane_y
	ctx.state.items.update_item(item)

	var spawned_event := SimEvent.new(ctx.tick, SimEvent.EventType.ITEM_AIRPLANE_DROPPED)
	spawned_event.payload = {
		"item_id": item_id,
		"item_type": item_type,
		"battle_item_id": battle_item_id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"scatter_from_x": int(pool.airplane_x),
		"scatter_from_y": pool.airplane_y,
	}
	ctx.events.push(spawned_event)


func _pick_airplane_row(ctx: SimContext) -> int:
	# 从右侧中心飞向左侧中心，在中部 1/3 区域选行
	var mid := int(ctx.state.grid.height / 2)
	var spread := maxi(1, int(ctx.state.grid.height / 6))
	return int(ctx.rng.range_int(mid - spread, mid + spread + 1))


func _find_drop_cell(ctx: SimContext, pool) -> Vector2i:
	# 在飞机当前位置附近找空 EMPTY 格子
	var center_x: int = int(pool.airplane_x)
	var center_y: int = int(pool.airplane_y)
	var grid := ctx.state.grid
	for dy in range(-2, 3):
		for dx in range(-1, 2):
			var cx := center_x + dx
			var cy := center_y + dy
			if not grid.is_in_bounds(cx, cy):
				continue
			if grid.get_static_cell(cx, cy).tile_type != TileConstantsScript.TileType.EMPTY:
				continue
			if _is_cell_occupied(ctx, cx, cy):
				continue
			if _is_drop_blocked(pool, cx, cy):
				continue
			return Vector2i(cx, cy)

	# 回退：搜索整个网格
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_static_cell(x, y).tile_type != TileConstantsScript.TileType.EMPTY:
				continue
			if _is_cell_occupied(ctx, x, y):
				continue
			if _is_drop_blocked(pool, x, y):
				continue
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _is_drop_blocked(pool, cell_x: int, cell_y: int) -> bool:
	return pool.blocked_drop_cells.has("%d,%d" % [cell_x, cell_y])


func _is_cell_occupied(ctx: SimContext, cell_x: int, cell_y: int) -> bool:
	if ctx.queries.get_bubble_at(cell_x, cell_y) != -1:
		return true
	for item_id in ctx.state.items.active_ids:
		var item: ItemState = ctx.state.items.get_item(item_id)
		if item != null and item.alive and item.cell_x == cell_x and item.cell_y == cell_y:
			return true
	return false


func _should_suppress_authority_entity_side_effects(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.suppress_authority_entity_side_effects)
