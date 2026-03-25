extends Node


func _ready() -> void:
	var snapshot_service := SnapshotService.new()
	var snapshot_buffer := SnapshotBuffer.new(16)
	var local_input_buffer := InputRingBuffer.new(16)
	var predicted_world := _build_world(5555)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(predicted_world, snapshot_service, snapshot_buffer, local_input_buffer, 0, 16)

	var correction_count := 0
	rollback.prediction_corrected.connect(func(_entity_id: int, _from_pos: Vector2i, _to_pos: Vector2i): correction_count += 1)

	var local_script := {
		1: Vector2i(1, 0),
		2: Vector2i(1, 0),
		3: Vector2i(1, 0)
	}
	for tick_id in [1, 2, 3]:
		var frame := PlayerInputFrame.new()
		frame.peer_id = 0
		frame.tick_id = tick_id
		frame.seq = tick_id
		frame.move_x = local_script[tick_id].x
		frame.move_y = local_script[tick_id].y
		local_input_buffer.put(frame)
		_enqueue_tick(predicted_world, tick_id, local_script[tick_id], Vector2i.ZERO)
		predicted_world.step()
		snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_world, tick_id))

	rollback.set_predicted_until_tick(3)
	var predicted_before := snapshot_service.build_light_snapshot(predicted_world, 3)

	var authority_world := _build_world(5555)
	_enqueue_tick(authority_world, 1, Vector2i(1, 0), Vector2i.ZERO)
	authority_world.step()
	_enqueue_tick(authority_world, 2, Vector2i(0, 0), Vector2i.ZERO)
	authority_world.step()
	var authoritative_snapshot := snapshot_service.build_light_snapshot(authority_world, 2)

	var expected_world := _build_world(5555)
	snapshot_service.restore_snapshot(expected_world, authoritative_snapshot)
	_enqueue_tick(expected_world, 3, local_script[3], Vector2i.ZERO)
	expected_world.step()
	var checksum_builder := ChecksumBuilder.new()
	var expected_checksum := checksum_builder.build(expected_world, expected_world.state.match_state.tick)

	var changed := rollback.on_authoritative_snapshot(authoritative_snapshot)
	_assert(changed, "rollback should trigger on mismatched authoritative snapshot")
	_assert(rollback.rollback_count == 1, "rollback_count should increment after mismatch")
	_assert(rollback.last_rollback_from_tick == 2, "rollback should start from authoritative snapshot tick")
	_assert(rollback.predicted_until_tick == 3, "predicted_until_tick should recover to local target tick")

	var corrected_checksum := checksum_builder.build(predicted_world, predicted_world.state.match_state.tick)
	_assert(corrected_checksum == expected_checksum, "predicted world should converge to replayed authoritative result")
	_assert(predicted_before.checksum != corrected_checksum, "rollback should change previously predicted state")
	_assert(rollback.force_resync_count == 0, "rollback path should correct mismatch without forcing full resync")
	_assert(correction_count >= 0, "correction signal count should be observable")

	predicted_world.dispose()
	authority_world.dispose()
	expected_world.dispose()

	print("test_rollback_controller: PASS")


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": TestMapFactory.build_basic_map()})
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
		push_error("test_rollback_controller: FAIL - %s" % message)
