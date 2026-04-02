extends Node


func _ready() -> void:
	var snapshot_service := SnapshotService.new()
	var snapshot_buffer := SnapshotBuffer.new(16)
	var local_input_buffer := InputRingBuffer.new(16)
	var predicted_world := _build_world(7070)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(predicted_world, snapshot_service, snapshot_buffer, local_input_buffer, 0, 16)

	for tick_id in [1, 2, 3]:
		var frame := PlayerInputFrame.new()
		frame.peer_id = 0
		frame.tick_id = tick_id
		frame.seq = tick_id
		frame.move_x = 1
		local_input_buffer.put(frame)
		_enqueue_tick(predicted_world, tick_id, Vector2i(1, 0), Vector2i.ZERO)
		predicted_world.step()
		snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_world, tick_id))

	rollback.set_predicted_until_tick(3)

	var server_world := _build_world(7070)
	_enqueue_tick(server_world, 1, Vector2i(0, 0), Vector2i.ZERO)
	server_world.step()
	_enqueue_tick(server_world, 2, Vector2i(0, 0), Vector2i.ZERO)
	server_world.step()
	var server_snapshot := snapshot_service.build_light_snapshot(server_world, 2)

	var changed := rollback.on_checksum_mismatch(2, server_snapshot)
	_assert(changed, "checksum mismatch with server snapshot should trigger correction")
	_assert(rollback.rollback_count == 1, "checksum mismatch should take rollback path when snapshot is provided")
	_assert(rollback.force_resync_count == 0, "checksum mismatch should not force resync when rollback is possible")
	_assert(predicted_world.state.match_state.tick == 3, "rollback should replay back to predicted frontier")

	var checksum_builder := ChecksumBuilder.new()
	var corrected_checksum := checksum_builder.build(predicted_world, predicted_world.state.match_state.tick)

	var expected_world := _build_world(7070)
	snapshot_service.restore_snapshot(expected_world, server_snapshot)
	_enqueue_tick(expected_world, 3, Vector2i(1, 0), Vector2i.ZERO)
	expected_world.step()
	var expected_checksum := checksum_builder.build(expected_world, expected_world.state.match_state.tick)
	_assert(corrected_checksum == expected_checksum, "checksum mismatch recovery should converge to expected replayed state")

	rollback.dispose()
	rollback.free()
	predicted_world.dispose()
	server_world.dispose()
	expected_world.dispose()

	print("test_checksum_mismatch_recovery: PASS")


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _enqueue_tick(world: SimWorld, tick_id: int, local_move: Vector2i, remote_move: Vector2i) -> void:
	var frame := InputFrame.new()
	frame.tick = tick_id
	frame.set_command(0, _command(local_move.x, local_move.y))
	frame.set_command(1, _command(remote_move.x, remote_move.y))
	world.enqueue_input(frame)


func _command(move_x: int, move_y: int) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	return command


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_checksum_mismatch_recovery: FAIL - %s" % message)

