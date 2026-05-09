extends QQTUnitTest

const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func test_step_players_matches_runtime_availability_contract() -> void:
	var world := _build_world(13579)
	var ctx := SimContext.new()
	ctx.state = world.state
	ctx.queries = world.queries
	var bridge := NativeMovementBridge.new()

	var result := bridge.step_players(ctx, world.state.players.active_ids)
	var expected_updates := 0
	if NativeKernelRuntimeScript.is_available() and NativeKernelRuntimeScript.has_movement_kernel():
		expected_updates = world.state.players.active_ids.size()

	assert_eq(
		result.get("player_updates", []).size(),
		expected_updates,
		"movement bridge should match runtime availability contract"
	)
	assert_true(result.has("blocked_events"), "movement bridge result should expose blocked_events")
	assert_true(result.has("cell_changes"), "movement bridge result should expose cell_changes")
	assert_true(result.has("bubble_phase_updates"), "movement bridge result should expose bubble_phase_updates")
	world.dispose()


func _build_world(rng_seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(rng_seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world
