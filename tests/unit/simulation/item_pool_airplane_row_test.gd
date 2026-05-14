extends "res://tests/gut/base/qqt_unit_test.gd"

const ItemPoolSystemScript = preload("res://gameplay/simulation/systems/item_pool_system.gd")
const ItemPoolRuntimeScript = preload("res://gameplay/simulation/entities/item_pool_runtime.gd")
const SimConfigScript = preload("res://gameplay/simulation/runtime/sim_config.gd")
const SimEventBufferScript = preload("res://gameplay/simulation/events/sim_event_buffer.gd")
const SimContextScript = preload("res://gameplay/simulation/runtime/sim_context.gd")


func test_main() -> void:
	_test_airplane_row_is_fixed_to_map_middle()
	_test_airplane_drops_items_in_three_even_phases()


func _test_airplane_row_is_fixed_to_map_middle() -> void:
	var system := ItemPoolSystemScript.new()
	var ctx := SimContextScript.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(15, 13)
	var picked := system._pick_airplane_row(ctx)
	assert_eq(picked, 6, "airplane row should use deterministic middle row for odd height")

	ctx.state.grid.initialize(15, 12)
	picked = system._pick_airplane_row(ctx)
	assert_eq(picked, 6, "airplane row should use deterministic middle row for even height")


func _test_airplane_drops_items_in_three_even_phases() -> void:
	var system := ItemPoolSystemScript.new()
	var ctx := SimContextScript.new()
	ctx.state = SimState.new()
	ctx.state.grid = GridState.new()
	ctx.state.grid.initialize(15, 13)
	ctx.config = SimConfigScript.new()
	ctx.config.item_defs = {
		"test_drop_item": {
			"item_type": 1,
			"pool_category": "default",
		}
	}
	ctx.events = SimEventBufferScript.new()
	ctx.events.begin_tick(100)

	var pool = ItemPoolRuntimeScript.new()
	pool.airplane_active = true
	pool.airplane_x = float(ctx.state.grid.width)
	pool.airplane_y = 6
	pool.airplane_drop_plan_total = 3
	pool.airplane_drop_plan_done = 0
	pool.recycle_pool = {"test_drop_item": 3}
	ctx.state.item_pool_runtime = pool

	system.debug_rebuild_drop_cell_cache(ctx, pool)
	while pool.airplane_active:
		system._tick_airplane(ctx, pool)

	assert_eq(pool.airplane_drop_plan_done, 0, "drop plan should reset when airplane despawns")
	assert_eq(ctx.state.items.active_ids.size(), 3, "airplane should complete 3 item drops per flight")
