extends Node

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")


func _ready() -> void:
	var snapshot_service := SnapshotService.new()
	var snapshot_buffer := SnapshotBuffer.new(16)
	var local_input_buffer := InputRingBuffer.new(16)
	var predicted_world := _build_world(9191)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(predicted_world, snapshot_service, snapshot_buffer, local_input_buffer, 0, 16)

	var captured_from := Vector2i.ZERO
	var captured_to := Vector2i.ZERO
	var correction_count := 0
	rollback.prediction_corrected.connect(func(_entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
		correction_count += 1
		captured_from = from_pos
		captured_to = to_pos
	)

	var local_frame := PlayerInputFrame.new()
	local_frame.peer_id = 0
	local_frame.tick_id = 1
	local_frame.seq = 1
	local_frame.move_x = 1
	local_input_buffer.put(local_frame)

	_enqueue_tick(predicted_world, 1, Vector2i(1, 0), Vector2i.ZERO)
	predicted_world.step()
	snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_world, 1))
	rollback.set_predicted_until_tick(1)

	var predicted_player := predicted_world.state.players.get_player(predicted_world.state.players.active_ids[0])
	var predicted_fp_before := GridMotionMath.get_player_abs_pos(predicted_player)

	var authority_world := _build_world(9191)
	_enqueue_tick(authority_world, 1, Vector2i.ZERO, Vector2i.ZERO)
	authority_world.step()
	var authoritative_snapshot := snapshot_service.build_light_snapshot(authority_world, 1)
	var authoritative_player := authority_world.state.players.get_player(authority_world.state.players.active_ids[0])
	var authoritative_fp := GridMotionMath.get_player_abs_pos(authoritative_player)

	var changed := rollback.on_authoritative_snapshot(authoritative_snapshot)
	_assert(changed, "same-cell subcell divergence should trigger rollback")
	_assert(correction_count > 0, "subcell mismatch should emit correction signal")
	_assert(captured_from == predicted_fp_before, "correction signal exposes predicted fp position")
	_assert(captured_to == authoritative_fp, "correction signal exposes authoritative fp position")
	_assert(captured_from != captured_to, "subcell correction should distinguish same-cell offset mismatch")

	var corrected_player := predicted_world.state.players.get_player(predicted_world.state.players.active_ids[0])
	var corrected_fp := GridMotionMath.get_player_abs_pos(corrected_player)
	_assert(corrected_fp == authoritative_fp, "predicted world converges to authoritative fp position")
	_assert(corrected_player.cell_x == authoritative_player.cell_x, "subcell correction may keep same foot cell")

	rollback.dispose()
	rollback.free()
	predicted_world.dispose()
	authority_world.dispose()

	print("test_rollback_subcell_correction: PASS")


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
		push_error("test_rollback_subcell_correction: FAIL - %s" % message)
