extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")


func test_main() -> void:
	var run_a := _run_chain_case(20260407)
	var run_b := _run_chain_case(20260407)

	_assert(run_a["checksums"] == run_b["checksums"], "checksum sequence should match across identical chain runs")
	_assert(run_a["exploded_ids"] == run_b["exploded_ids"], "exploded bubble ordering should match across identical chain runs")
	_assert(run_a["final_checksum"] == run_b["final_checksum"], "final checksum should match across identical chain runs")



func _run_chain_case(seed: int) -> Dictionary:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory._build_from_rows([
		"#######",
		"#S....#",
		"#.....#",
		"#....S#",
		"#######",
	])})
	world.config.system_flags["explosion_reaction"] = BattleExplosionConfigBuilder.new().build_for_rule("ruleset_classic")
	world.state.bubbles.spawn_bubble(1, 2, 2, 1, 1)
	world.state.bubbles.spawn_bubble(1, 3, 2, 1, 999)
	world.state.bubbles.spawn_bubble(1, 4, 2, 1, 999)
	world.state.indexes.rebuild_from_state(world.state)

	var checksum_builder := ChecksumBuilder.new()
	var checksums: Array[int] = []
	var exploded_ids: Array[int] = []

	for _step_index in range(2):
		var result := world.step()
		checksums.append(checksum_builder.build(world, world.state.match_state.tick))
		for event in result.get("events", []):
			if event != null and int(event.event_type) == SimEvent.EventType.BUBBLE_EXPLODED:
				exploded_ids.append(int(event.payload.get("bubble_id", -1)))

	var summary := {
		"checksums": checksums,
		"exploded_ids": exploded_ids,
		"final_checksum": checksums[-1] if not checksums.is_empty() else 0,
	}
	world.dispose()
	return summary


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

