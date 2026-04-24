extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_rollback_controller_matches_native_snapshot_ring_path() -> void:
	var baseline_result := _run_rollback_sequence(false)
	var native_result := _run_rollback_sequence(true)

	assert_eq(native_result["snapshot"], baseline_result["snapshot"], "native rollback should match baseline snapshot result")
	assert_eq(native_result["rollback_count"], baseline_result["rollback_count"], "native rollback should match rollback count")
	assert_eq(native_result["predicted_until_tick"], baseline_result["predicted_until_tick"], "native rollback should replay to same tick")


func _run_rollback_sequence(use_native_snapshot_ring: bool) -> Dictionary:
	var previous_flag := NativeFeatureFlagsScript.enable_native_snapshot_ring
	NativeFeatureFlagsScript.enable_native_snapshot_ring = use_native_snapshot_ring
	var snapshot_service := SnapshotService.new()
	var predicted_world := _build_world(9201)
	var authoritative_world := _build_world(9201)
	var snapshot_buffer := SnapshotBuffer.new(8)
	var input_buffer := InputRingBuffer.new(8)
	var rollback_controller := RollbackController.new()

	for tick_id in range(1, 5):
		var frame := PlayerInputFrame.new()
		frame.peer_id = 0
		frame.tick_id = tick_id
		frame.seq = tick_id
		frame.move_x = 1
		input_buffer.put(frame)

		_apply_player_input(predicted_world, 0, tick_id, 1, 0)
		predicted_world.step()
		snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_world, tick_id))
		if tick_id <= 2:
			_apply_player_input(authoritative_world, 0, tick_id, 0, 0)
			authoritative_world.step()

	rollback_controller.configure(
		predicted_world,
		snapshot_service,
		snapshot_buffer,
		input_buffer,
		0
	)
	rollback_controller.set_predicted_until_tick(4)
	rollback_controller.on_authoritative_snapshot(snapshot_service.build_light_snapshot(authoritative_world, 2))

	var result := {
		"snapshot": snapshot_service.build_light_snapshot(predicted_world, predicted_world.state.match_state.tick).players,
		"rollback_count": rollback_controller.rollback_count,
		"predicted_until_tick": rollback_controller.predicted_until_tick,
	}
	rollback_controller.dispose()
	NativeFeatureFlagsScript.enable_native_snapshot_ring = previous_flag
	predicted_world.dispose()
	authoritative_world.dispose()
	return result


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	player.speed_level = 3
	world.state.players.update_player(player)
	return world


func _apply_player_input(world: SimWorld, player_slot: int, tick_id: int, move_x: int, move_y: int) -> void:
	var input_frame := InputFrame.new()
	input_frame.tick = tick_id
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	input_frame.set_command(player_slot, command)
	world.enqueue_input(input_frame)
