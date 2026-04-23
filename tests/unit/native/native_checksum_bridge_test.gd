extends QQTUnitTest


func test_build_falls_back_to_gdscript_checksum_when_native_unavailable() -> void:
	var world := _build_world(24680)
	var tick_id := world.state.match_state.tick
	var checksum_builder := ChecksumBuilder.new()
	var native_bridge := NativeChecksumBridge.new()

	var expected := checksum_builder.build(world, tick_id)
	var actual := native_bridge.build(world, tick_id)

	assert_eq(actual, expected, "native checksum bridge should fallback to formal GDScript checksum")
	world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world
