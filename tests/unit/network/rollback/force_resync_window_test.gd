extends Node


func _ready() -> void:
	var snapshot_service := SnapshotService.new()
	var snapshot_buffer := SnapshotBuffer.new(16)
	var local_input_buffer := InputRingBuffer.new(16)
	var predicted_world := _build_world(6060)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(predicted_world, snapshot_service, snapshot_buffer, local_input_buffer, 0, 1)

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

	var authority_world := _build_world(6060)
	_enqueue_tick(authority_world, 1, Vector2i(0, 0), Vector2i.ZERO)
	authority_world.step()
	var authoritative_snapshot := snapshot_service.build_standard_snapshot(authority_world, 1)

	var changed := rollback.on_authoritative_snapshot(authoritative_snapshot)
	_assert(changed, "far authoritative snapshot should require correction")
	_assert(rollback.force_resync_count == 1, "out-of-window mismatch should force resync")
	_assert(rollback.rollback_count == 0, "force resync path should skip rollback replay")
	_assert(predicted_world.state.match_state.tick == 1, "predicted world should snap to authoritative tick")
	_assert(rollback.predicted_until_tick == 1, "force resync should reset predicted frontier to snapshot tick")

	rollback.dispose()
	rollback.free()
	predicted_world.dispose()
	authority_world.dispose()

	print("test_force_resync_window: PASS")


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
		push_error("test_force_resync_window: FAIL - %s" % message)

