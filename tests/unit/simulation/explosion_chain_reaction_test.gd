extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")


func _ready() -> void:
	var ok := true
	ok = _test_bubble_chain_resolves_in_same_tick() and ok
	if ok:
		print("explosion_chain_reaction_test: PASS")


func _test_bubble_chain_resolves_in_same_tick() -> bool:
	var world := _make_world()
	world.config.system_flags["explosion_reaction"] = BattleExplosionConfigBuilder.new().build_for_rule("ruleset_classic")
	var bubble_a := world.state.bubbles.spawn_bubble(1, 2, 2, 1, 1)
	var bubble_b := world.state.bubbles.spawn_bubble(2, 3, 2, 1, 999)
	world.state.indexes.rebuild_from_state(world.state)

	var result := world.step()
	var events: Array = result.get("events", [])
	var exploded_bubble_ids: Array[int] = []
	for event in events:
		if event != null and int(event.event_type) == SimEvent.EventType.BUBBLE_EXPLODED:
			exploded_bubble_ids.append(int(event.payload.get("bubble_id", -1)))

	var prefix := "explosion_chain_reaction_test"
	var ok := true
	ok = TestAssert.is_true(world.state.bubbles.get_bubble(bubble_a) != null and not world.state.bubbles.get_bubble(bubble_a).alive, "source bubble should explode", prefix) and ok
	ok = TestAssert.is_true(world.state.bubbles.get_bubble(bubble_b) != null and not world.state.bubbles.get_bubble(bubble_b).alive, "chained bubble should also explode in same tick", prefix) and ok
	ok = TestAssert.is_true(exploded_bubble_ids.size() == 2, "same tick chain should emit two BUBBLE_EXPLODED events", prefix) and ok
	ok = TestAssert.is_true(exploded_bubble_ids.count(bubble_a) == 1 and exploded_bubble_ids.count(bubble_b) == 1, "each chained bubble should explode exactly once", prefix) and ok
	world.dispose()
	return ok


func _make_world() -> SimWorld:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory._build_from_rows([
		"#######",
		"#S....#",
		"#.....#",
		"#....S#",
		"#######",
	])})
	return world
