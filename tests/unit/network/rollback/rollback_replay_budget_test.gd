extends "res://tests/gut/base/qqt_unit_test.gd"


func test_large_replay_uses_force_resync_instead_of_sync_rollback() -> void:
	var snapshot_service := SnapshotService.new()
	var snapshot_buffer := SnapshotBuffer.new(128)
	var local_input_buffer := InputRingBuffer.new(128)
	var predicted_world := _build_world(2468)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(predicted_world, snapshot_service, snapshot_buffer, local_input_buffer, 0, 64)

	var authority_world := _build_world(2468)
	for tick_id in range(1, 11):
		_enqueue_idle_tick(authority_world, tick_id)
		authority_world.step()
	var authoritative_snapshot := snapshot_service.build_light_snapshot(authority_world, 10)

	rollback.set_predicted_until_tick(50)
	rollback._rollback_from_snapshot(authoritative_snapshot)

	assert_eq(rollback.rollback_count, 0)
	assert_eq(rollback.force_resync_count, 1)
	assert_eq(rollback.last_replay_tick_count, 0)
	assert_eq(rollback.predicted_until_tick, 10)

	rollback.dispose()
	rollback.free()
	predicted_world.dispose()
	authority_world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _enqueue_idle_tick(world: SimWorld, tick_id: int) -> void:
	var frame := InputFrame.new()
	frame.tick = tick_id
	frame.set_command(0, PlayerCommand.neutral())
	frame.set_command(1, PlayerCommand.neutral())
	world.enqueue_input(frame)
