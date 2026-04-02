extends Node


func _ready() -> void:
	var map_data = BuiltinMapFactory.build_basic_map()
	var world_a := _build_world(31415, map_data)
	var world_b := _build_world(31415, map_data)
	var checksum_builder := ChecksumBuilder.new()

	_run_scripted_ticks(world_a)
	_run_scripted_ticks(world_b)

	var tick_id := world_a.state.match_state.tick
	var checksum_a := checksum_builder.build(world_a, tick_id)
	var checksum_b := checksum_builder.build(world_b, tick_id)
	_assert(checksum_a == checksum_b, "same state should produce same checksum")

	var player_id := world_b.state.players.active_ids[0]
	var player := world_b.state.players.get_player(player_id)
	player.bomb_range += 1
	world_b.state.players.update_player(player)

	var mutated_checksum := checksum_builder.build(world_b, world_b.state.match_state.tick)
	_assert(mutated_checksum != checksum_a, "logic field mutation should change checksum")

	world_a.dispose()
	world_b.dispose()

	print("checksum_builder_test: PASS")


func _build_world(seed: int, map_data) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": map_data})
	return world


func _run_scripted_ticks(world: SimWorld) -> void:
	var scripts := [
		{0: _command(1, 0, false), 1: _command(-1, 0, false)},
		{0: _command(0, 0, true), 1: _command(0, 1, false)},
		{0: _command(0, 0, false), 1: _command(0, 0, false)}
	]

	for entry in scripts:
		var frame := InputFrame.new()
		frame.tick = world.state.match_state.tick + 1
		for slot in entry.keys():
			frame.set_command(int(slot), entry[slot])
		world.enqueue_input(frame)
		world.step()


func _command(move_x: int, move_y: int, place_bubble: bool) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	command.place_bubble = place_bubble
	return command


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("checksum_builder_test: FAIL - %s" % message)
