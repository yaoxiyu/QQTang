extends Node


func _ready() -> void:
	var script := _build_replay_script()
	var run_a := _run_replay(script, 20260325)
	var run_b := _run_replay(script, 20260325)

	_assert(run_a["checksums"] == run_b["checksums"], "checksum sequence should be stable across replay runs")
	_assert(run_a["final_checksum"] == run_b["final_checksum"], "final checksum should match across replay runs")
	_assert(run_a["final_tick"] == run_b["final_tick"], "final tick should match across replay runs")

	print("test_replay_determinism: PASS")


func _run_replay(script: Array[Dictionary], seed: int) -> Dictionary:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": TestMapFactory.build_basic_map()})

	var checksum_builder := ChecksumBuilder.new()
	var checksums: Array[int] = []

	for entry in script:
		var frame := InputFrame.new()
		frame.tick = world.state.match_state.tick + 1
		for slot in entry.keys():
			frame.set_command(int(slot), entry[slot])
		world.enqueue_input(frame)
		world.step()
		checksums.append(checksum_builder.build(world, world.state.match_state.tick))

	var result := {
		"checksums": checksums,
		"final_checksum": checksums[-1] if not checksums.is_empty() else 0,
		"final_tick": world.state.match_state.tick
	}
	world.dispose()
	return result


func _build_replay_script() -> Array[Dictionary]:
	return [
		{0: _command(1, 0, false), 1: _command(-1, 0, false)},
		{0: _command(0, 0, true), 1: _command(0, 1, false)},
		{0: _command(0, 0, false), 1: _command(0, 0, false)},
		{0: _command(0, 0, false), 1: _command(0, -1, false)},
		{0: _command(1, 0, false), 1: _command(0, 0, false)},
		{0: _command(0, 0, false), 1: _command(0, 0, true)}
	]


func _command(move_x: int, move_y: int, place_bubble: bool) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	command.place_bubble = place_bubble
	return command


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_replay_determinism: FAIL - %s" % message)
