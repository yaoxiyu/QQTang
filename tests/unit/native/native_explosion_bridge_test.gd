extends QQTUnitTest


func test_resolve_returns_empty_result_when_native_unavailable() -> void:
	var world := _build_world(11223)
	var ctx := SimContext.new()
	ctx.tick = world.state.match_state.tick
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.scratch = SimScratch.new()
	ctx.scratch.bubbles_to_explode.append(99)
	var bridge := NativeExplosionBridge.new()

	var result := bridge.resolve(ctx)

	assert_eq(result.get("covered_cells", []).size(), 0, "explosion bridge should not emit covered cells on fallback")
	assert_eq(result.get("hit_entries", []).size(), 0, "explosion bridge should not emit hit entries on fallback")
	assert_eq(result.get("destroy_cells", []).size(), 0, "explosion bridge should not emit destroy cells on fallback")
	assert_eq(result.get("chain_bubble_ids", []).size(), 0, "explosion bridge should not emit chain ids on fallback")
	assert_eq(result.get("processed_bubble_ids", []).size(), 0, "explosion bridge should not emit processed ids on fallback")
	world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world
