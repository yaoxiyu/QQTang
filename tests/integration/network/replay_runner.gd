class_name ReplayRunner
extends RefCounted


func run(seed: int, input_log: Array[Dictionary], map_data = null) -> Dictionary:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": map_data if map_data != null else BuiltinMapFactory.build_basic_map()})

	var checksum_builder := ChecksumBuilder.new()
	var checksum_sequence: Array[int] = []

	for entry in input_log:
		var frame := InputFrame.new()
		frame.tick = world.state.match_state.tick + 1
		for slot in entry.keys():
			frame.set_command(int(slot), entry[slot])
		world.enqueue_input(frame)
		world.step()
		checksum_sequence.append(checksum_builder.build(world, world.state.match_state.tick))

	var final_checksum := 0
	if not checksum_sequence.is_empty():
		final_checksum = checksum_sequence[-1]
	world.dispose()
	return {
		"checksum_sequence": checksum_sequence,
		"final_checksum": final_checksum,
		"final_tick": world.state.match_state.tick
	}
