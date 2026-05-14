extends "res://tests/gut/base/qqt_unit_test.gd"

const ItemPoolSystemScript = preload("res://gameplay/simulation/systems/item_pool_system.gd")
const ItemPoolRuntimeScript = preload("res://gameplay/simulation/entities/item_pool_runtime.gd")


func test_main() -> void:
	_test_find_drop_cell_skips_blocked_surface_or_channel_cells()
	_test_find_drop_cell_allows_cells_occupied_by_bubble_or_item()
	_test_find_drop_cell_uses_global_cache()
	_test_drop_cell_cache_updates_when_breakable_destroyed()


func _test_find_drop_cell_skips_blocked_surface_or_channel_cells() -> void:
	var ctx := SimContext.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(3, 3)
	_fill_grid_with_solid(ctx.state.grid)
	ctx.state.grid.set_static_cell(1, 1, TileFactory.make_empty())
	ctx.state.grid.set_static_cell(2, 1, TileFactory.make_empty())

	var pool = ItemPoolRuntimeScript.new()
	pool.airplane_x = 1.0
	pool.airplane_y = 1
	pool.blocked_drop_cells["1,1"] = true
	ctx.state.item_pool_runtime = pool

	var system = ItemPoolSystemScript.new()
	system.debug_rebuild_drop_cell_cache(ctx, pool)
	var drop_cell := system._find_drop_cell(ctx, pool)
	assert_eq(drop_cell, Vector2i(2, 1), "drop cell should skip blocked (surface/channel) empty cell")


func _test_find_drop_cell_allows_cells_occupied_by_bubble_or_item() -> void:
	var ctx := SimContext.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(3, 3)
	_fill_grid_with_solid(ctx.state.grid)
	ctx.state.grid.set_static_cell(1, 1, TileFactory.make_empty())

	var pool = ItemPoolRuntimeScript.new()
	pool.airplane_x = 1.0
	pool.airplane_y = 1
	ctx.state.item_pool_runtime = pool

	var system = ItemPoolSystemScript.new()
	system.debug_rebuild_drop_cell_cache(ctx, pool)
	var drop_cell := system._find_drop_cell(ctx, pool)
	assert_eq(drop_cell, Vector2i(1, 1), "drop cell should be selected from full-map cache")


func _fill_grid_with_solid(grid: GridState) -> void:
	for y in range(grid.height):
		for x in range(grid.width):
			grid.set_static_cell(x, y, TileFactory.make_solid_wall())


func _test_find_drop_cell_uses_global_cache() -> void:
	var ctx := SimContext.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(9, 9)
	_fill_grid_with_solid(ctx.state.grid)

	# 附近区域全部不可投放（非 EMPTY）
	for y in range(2, 7):
		for x in range(2, 7):
			ctx.state.grid.set_static_cell(x, y, TileFactory.make_solid_wall())

	# 全图只有远处一个 EMPTY，按新规则应命中这个全图缓存候选。
	ctx.state.grid.set_static_cell(0, 0, TileFactory.make_empty())

	var pool = ItemPoolRuntimeScript.new()
	pool.airplane_x = 4.0
	pool.airplane_y = 4
	ctx.state.item_pool_runtime = pool

	var system = ItemPoolSystemScript.new()
	system.debug_rebuild_drop_cell_cache(ctx, pool)
	var drop_cell := system._find_drop_cell(ctx, pool)
	assert_eq(drop_cell, Vector2i(0, 0), "airdrop should randomly pick from full-map cached drop cells")


func _test_drop_cell_cache_updates_when_breakable_destroyed() -> void:
	var ctx := SimContext.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(3, 3)
	_fill_grid_with_solid(ctx.state.grid)
	ctx.state.grid.set_static_cell(1, 1, TileFactory.make_breakable_block())
	ctx.events = SimEventBuffer.new()
	ctx.events.begin_tick(1)

	var pool := ItemPoolRuntimeScript.new()
	ctx.state.item_pool_runtime = pool

	var system := ItemPoolSystemScript.new()
	system.debug_rebuild_drop_cell_cache(ctx, pool)
	assert_false(system.debug_is_cell_cached(pool, 1, 1), "breakable cell should not exist in initial cache")

	ctx.state.grid.set_static_cell(1, 1, TileFactory.make_empty())
	var destroyed_event := SimEvent.new(1, SimEvent.EventType.CELL_DESTROYED)
	destroyed_event.payload = {"cell_x": 1, "cell_y": 1}
	ctx.events.push(destroyed_event)
	system._sync_drop_cell_cache_from_destroyed_cells(ctx, pool)
	assert_true(system.debug_is_cell_cached(pool, 1, 1), "destroyed cell should be inserted into cached candidates immediately")
