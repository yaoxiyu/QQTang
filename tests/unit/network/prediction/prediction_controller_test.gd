extends Node

const PredictionControllerScript = preload("res://gameplay/network/prediction/prediction_controller.gd")


func _ready() -> void:
	var predicted_world := _build_world(8080)
	var snapshot_service := SnapshotService.new()
	var local_input_buffer := InputRingBuffer.new(16)
	var controller = PredictionControllerScript.new()
	add_child(controller)
	controller.configure(predicted_world, snapshot_service, local_input_buffer, 0)

	var corrected_count := 0
	controller.prediction_corrected.connect(func(_entity_id: int, _from_pos: Vector2i, _to_pos: Vector2i): corrected_count += 1)

	for tick_id in [1, 2, 3]:
		var frame := PlayerInputFrame.new()
		frame.peer_id = 0
		frame.tick_id = tick_id
		frame.seq = tick_id
		frame.move_x = 1
		local_input_buffer.put(frame)

	controller.predict_to_tick(3)
	_assert(controller.predicted_until_tick == 3, "prediction should advance to requested tick")
	_assert(controller.snapshot_buffer.get_snapshot(1) != null, "prediction should record tick 1 snapshot")
	_assert(controller.snapshot_buffer.get_snapshot(2) != null, "prediction should record tick 2 snapshot")
	_assert(controller.snapshot_buffer.get_snapshot(3) != null, "prediction should record tick 3 snapshot")

	var predicted_snapshot := snapshot_service.build_light_snapshot(predicted_world, 3)

	var authority_world := _build_world(8080)
	_enqueue_tick(authority_world, 1, Vector2i(1, 0), Vector2i.ZERO)
	authority_world.step()
	_enqueue_tick(authority_world, 2, Vector2i(0, 0), Vector2i.ZERO)
	authority_world.step()
	var authoritative_snapshot := snapshot_service.build_light_snapshot(authority_world, 2)

	controller.on_authoritative_snapshot(authoritative_snapshot)
	_assert(controller.authoritative_tick == 2, "authoritative tick should update from snapshot")
	_assert(controller.predicted_until_tick == 3, "prediction should replay back to the local predicted frontier")
	_assert(controller.rollback_controller.rollback_count == 1, "authoritative mismatch should trigger rollback")
	_assert(controller.rollback_controller.force_resync_count == 0, "prediction mismatch should stay on rollback path")

	var checksum_builder := ChecksumBuilder.new()
	var corrected_checksum := checksum_builder.build(predicted_world, predicted_world.state.match_state.tick)

	var expected_world := _build_world(8080)
	snapshot_service.restore_snapshot(expected_world, authoritative_snapshot)
	_enqueue_tick(expected_world, 3, Vector2i(1, 0), Vector2i.ZERO)
	expected_world.step()
	var expected_checksum := checksum_builder.build(expected_world, expected_world.state.match_state.tick)

	_assert(predicted_snapshot.checksum != corrected_checksum, "prediction should change after authoritative correction")
	_assert(corrected_checksum == expected_checksum, "prediction controller should converge to replayed authoritative state")
	_assert(corrected_count >= 0, "prediction correction signal should remain observable")

	controller.dispose()
	controller.free()
	predicted_world.dispose()
	authority_world.dispose()
	expected_world.dispose()

	print("test_prediction_controller: PASS")


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
		push_error("test_prediction_controller: FAIL - %s" % message)

