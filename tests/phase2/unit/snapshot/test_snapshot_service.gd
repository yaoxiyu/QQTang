extends Node


func _ready() -> void:
	var map_data = TestMapFactory.build_basic_map()
	var world_a := _build_world(777, map_data)
	_run_scripted_ticks(world_a, _make_scripted_inputs())

	var snapshot_service := SnapshotService.new()
	var saved_tick := world_a.state.match_state.tick
	var standard_snapshot := snapshot_service.build_standard_snapshot(world_a, saved_tick)

	var world_b := _build_world(123, map_data)
	snapshot_service.restore_snapshot(world_b, standard_snapshot)
	var restored_snapshot := snapshot_service.build_standard_snapshot(world_b, saved_tick)
	var restored_diff := snapshot_service.build_diff(standard_snapshot, restored_snapshot)

	_assert(restored_diff["players_equal"], "restored players should match snapshot")
	_assert(restored_diff["bubbles_equal"], "restored bubbles should match snapshot")
	_assert(restored_diff["items_equal"], "restored items should match snapshot")
	_assert(restored_diff["walls_equal"], "restored walls should match snapshot")
	_assert(restored_diff["mode_equal"], "restored mode state should match snapshot")
	_assert(standard_snapshot.checksum == restored_snapshot.checksum, "restored checksum should match snapshot")

	var future_inputs := _make_future_inputs()
	_run_scripted_ticks(world_a, future_inputs)
	_run_scripted_ticks(world_b, future_inputs)

	var checksum_builder := ChecksumBuilder.new()
	var final_tick := world_a.state.match_state.tick
	var checksum_a := checksum_builder.build(world_a, final_tick)
	var checksum_b := checksum_builder.build(world_b, final_tick)
	_assert(checksum_a == checksum_b, "restored world should stay deterministic after future ticks")

	world_a.dispose()
	world_b.dispose()

	print("test_snapshot_service: PASS")


func _build_world(seed: int, map_data) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": map_data})
	return world


func _run_scripted_ticks(world: SimWorld, script: Array[Dictionary]) -> void:
	for entry in script:
		var frame := InputFrame.new()
		frame.tick = world.state.match_state.tick + 1
		for slot in entry.keys():
			var command: PlayerCommand = entry[slot]
			frame.set_command(int(slot), command)
		world.enqueue_input(frame)
		world.step()


func _make_scripted_inputs() -> Array[Dictionary]:
	var step_1 := {
		0: _command(1, 0, false),
		1: _command(-1, 0, false)
	}
	var step_2 := {
		0: _command(0, 0, true),
		1: _command(0, 0, false)
	}
	var step_3 := {
		0: _command(0, 0, false),
		1: _command(0, 1, false)
	}
	return [step_1, step_2, step_3]


func _make_future_inputs() -> Array[Dictionary]:
	var step_1 := {
		0: _command(0, 0, false),
		1: _command(0, 0, false)
	}
	var step_2 := {
		0: _command(1, 0, false),
		1: _command(0, -1, false)
	}
	return [step_1, step_2]


func _command(move_x: int, move_y: int, place_bubble: bool) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	command.place_bubble = place_bubble
	return command


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_snapshot_service: FAIL - %s" % message)
