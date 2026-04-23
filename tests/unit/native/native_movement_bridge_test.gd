extends QQTUnitTest


func test_step_players_returns_empty_result_when_native_unavailable() -> void:
	var world := _build_world(13579)
	var ctx := SimContext.new()
	ctx.state = world.state
	ctx.queries = world.queries
	var bridge := NativeMovementBridge.new()

	var result := bridge.step_players(ctx, world.state.players.active_ids)

	assert_eq(result.get("player_updates", []).size(), 0, "movement bridge should not mutate when native runtime is unavailable")
	assert_eq(result.get("blocked_events", []).size(), 0, "movement bridge should not emit blocked events on fallback")
	assert_eq(result.get("cell_changes", []).size(), 0, "movement bridge should not emit cell changes on fallback")
	assert_eq(result.get("bubble_ignore_removals", []).size(), 0, "movement bridge should not emit ignore removals on fallback")
	world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world
