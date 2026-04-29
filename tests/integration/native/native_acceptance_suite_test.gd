extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")


func test_native_acceptance_flow_preserves_world_parity_and_rollback_consistency() -> void:
	assert_true(NativeKernelRuntimeScript.get_kernel_version() != "", "native runtime should expose kernel version")

	var previous_checksum_flag := NativeFeatureFlagsScript.enable_native_checksum
	var previous_snapshot_flag := NativeFeatureFlagsScript.enable_native_snapshot_ring
	var previous_movement_flag := NativeFeatureFlagsScript.enable_native_movement
	var previous_explosion_flag := NativeFeatureFlagsScript.enable_native_explosion

	var snapshot_service := SnapshotService.new()
	var checksum_builder := ChecksumBuilder.new()
	var native_checksum_bridge := NativeChecksumBridge.new()

	var baseline_world := _build_world(9301)
	var native_world := _build_world(9301)
	var baseline_buffer := SnapshotBuffer.new(4)
	var native_buffer := SnapshotBuffer.new(4)

	_configure_acceptance_world(baseline_world)
	_configure_acceptance_world(native_world)

	var commands := _build_acceptance_command_sequence()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		var baseline_events := _step_world_with_flags(baseline_world, command, false)
		var native_events := _step_world_with_flags(native_world, command, true)
		var tick_id := baseline_world.state.match_state.tick

		var baseline_snapshot := snapshot_service.build_standard_snapshot(baseline_world, tick_id, false)
		baseline_snapshot.checksum = checksum_builder.build(baseline_world, tick_id)
		var native_snapshot := snapshot_service.build_standard_snapshot(native_world, tick_id, false)
		native_snapshot.checksum = native_checksum_bridge.build(native_world, tick_id)

		_put_snapshot_with_mode(baseline_buffer, baseline_snapshot, false)
		_put_snapshot_with_mode(native_buffer, native_snapshot, true)

		assert_eq(native_snapshot.players, baseline_snapshot.players, "native acceptance players mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.bubbles, baseline_snapshot.bubbles, "native acceptance bubbles mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.items, baseline_snapshot.items, "native acceptance items mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.walls, baseline_snapshot.walls, "native acceptance walls mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.match_state, baseline_snapshot.match_state, "native acceptance match_state mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.mode_state, baseline_snapshot.mode_state, "native acceptance mode_state mismatch at tick=%d" % tick_id)
		assert_eq(native_snapshot.checksum, baseline_snapshot.checksum, "native acceptance checksum mismatch at tick=%d" % tick_id)
		assert_eq(native_events, baseline_events, "native acceptance event mismatch at tick=%d" % tick_id)
		assert_eq(
			_serialize_snapshot(_get_snapshot_with_mode(native_buffer, tick_id, true)),
			_serialize_snapshot(_get_snapshot_with_mode(baseline_buffer, tick_id, false)),
			"native snapshot ring mismatch at tick=%d" % tick_id
		)

	assert_true(_get_snapshot_with_mode(baseline_buffer, 1, false) == null, "baseline buffer should evict tick 1")
	assert_true(_get_snapshot_with_mode(native_buffer, 1, true) == null, "native buffer should evict tick 1")
	assert_eq(
		_serialize_snapshot(_get_snapshot_with_mode(native_buffer, 6, true)),
		_serialize_snapshot(_get_snapshot_with_mode(baseline_buffer, 6, false)),
		"latest retained snapshot should match after eviction"
	)

	var baseline_rollback := _run_rollback_acceptance(false)
	var native_rollback := _run_rollback_acceptance(true)
	assert_eq(native_rollback, baseline_rollback, "native rollback acceptance result should match baseline")

	NativeFeatureFlagsScript.enable_native_checksum = previous_checksum_flag
	NativeFeatureFlagsScript.enable_native_snapshot_ring = previous_snapshot_flag
	NativeFeatureFlagsScript.enable_native_movement = previous_movement_flag
	NativeFeatureFlagsScript.enable_native_explosion = previous_explosion_flag
	baseline_world.dispose()
	native_world.dispose()


func test_native_movement_speed_levels_match_gdscript() -> void:
	var previous_movement_flag := NativeFeatureFlagsScript.enable_native_movement
	var previous_checksum_flag := NativeFeatureFlagsScript.enable_native_checksum
	var snapshot_service := SnapshotService.new()
	var speed_levels := [1, 3, 5, 7, 9]
	for speed_level in speed_levels:
		var baseline_world := _build_speed_parity_world(9400 + int(speed_level), int(speed_level))
		var native_world := _build_speed_parity_world(9400 + int(speed_level), int(speed_level))
		for _i in range(8):
			_step_world_with_flags(baseline_world, {"move": Vector2i.RIGHT, "place": false}, false)
			_step_world_with_flags(native_world, {"move": Vector2i.RIGHT, "place": false}, true)
		var tick_id := baseline_world.state.match_state.tick
		var baseline_snapshot := snapshot_service.build_light_snapshot(baseline_world, tick_id, false)
		var native_snapshot := snapshot_service.build_light_snapshot(native_world, tick_id, false)
		if native_snapshot.players != baseline_snapshot.players:
			LogSimulationScript.warn(
				"speed_level=%d baseline_players=%s native_players=%s" % [
					int(speed_level),
					str(baseline_snapshot.players),
					str(native_snapshot.players),
				],
				"",
				0,
				"simulation.movement.native_parity"
			)
		assert_eq(native_snapshot.players, baseline_snapshot.players, "native movement parity mismatch for speed_level=%d" % int(speed_level))
		baseline_world.dispose()
		native_world.dispose()
	NativeFeatureFlagsScript.enable_native_movement = previous_movement_flag
	NativeFeatureFlagsScript.enable_native_checksum = previous_checksum_flag


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _build_speed_parity_world(seed: int, speed_level: int) -> SimWorld:
	var world := _build_world(seed)
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	player.speed_level = speed_level
	player.max_speed_level = 9
	world.state.players.update_player(player)
	return world


func _configure_acceptance_world(world: SimWorld) -> void:
	var source_player_id := int(world.state.players.active_ids[0])
	var target_player_id := int(world.state.players.active_ids[1])

	var source_player := world.state.players.get_player(source_player_id)
	source_player.speed_level = 3
	source_player.bomb_available = 1
	source_player.bomb_range = 4
	world.state.players.update_player(source_player)

	var target_player := world.state.players.get_player(target_player_id)
	target_player.cell_x = 6
	target_player.cell_y = 4
	target_player.offset_x = 0
	target_player.offset_y = 0
	world.state.players.update_player(target_player)

	var move_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, source_player.cell_x, source_player.cell_y, 1, 30)
	var move_bubble := world.state.bubbles.get_bubble(move_bubble_id)
	move_bubble.ignore_player_ids = [source_player_id]
	world.state.bubbles.update_bubble(move_bubble)

	var source_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 6, 5, 4, 3)
	var chain_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 8, 5, 1, 3)
	var source_bubble := world.state.bubbles.get_bubble(source_bubble_id)
	var chain_bubble := world.state.bubbles.get_bubble(chain_bubble_id)
	source_bubble.owner_player_id = source_player_id
	chain_bubble.owner_player_id = source_player_id
	world.state.bubbles.update_bubble(source_bubble)
	world.state.bubbles.update_bubble(chain_bubble)

	var item_id := world.state.items.spawn_item(3, 6, 6, 0)
	var item := world.state.items.get_item(item_id)
	item.visible = true
	world.state.items.update_item(item)

	world.state.mode.mode_timer_ticks = 180
	world.state.mode.payload_owner_id = source_player_id
	world.state.mode.payload_cell_x = source_player.cell_x
	world.state.mode.payload_cell_y = source_player.cell_y
	world.state.mode.sudden_death_active = true
	world.state.indexes.rebuild_from_state(world.state)


func _build_acceptance_command_sequence() -> Array[Dictionary]:
	return [
		{"move": Vector2i.RIGHT, "place": false},
		{"move": Vector2i.RIGHT, "place": false},
		{"move": Vector2i.RIGHT, "place": false},
		{"move": Vector2i.DOWN, "place": false},
		{"move": Vector2i.ZERO, "place": false},
		{"move": Vector2i.ZERO, "place": false},
	]


func _step_world_with_flags(world: SimWorld, command: Dictionary, use_native: bool) -> Array[Dictionary]:
	NativeFeatureFlagsScript.enable_native_checksum = use_native
	NativeFeatureFlagsScript.enable_native_movement = use_native
	NativeFeatureFlagsScript.enable_native_explosion = use_native

	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	var player_command := PlayerCommand.neutral()
	var move: Vector2i = command.get("move", Vector2i.ZERO)
	player_command.move_x = move.x
	player_command.move_y = move.y
	player_command.place_bubble = bool(command.get("place", false))
	frame.set_command(player.player_slot, player_command)
	world.enqueue_input(frame)
	var result := world.step()
	return _serialize_events(result.get("events", []))


func _put_snapshot_with_mode(snapshot_buffer: SnapshotBuffer, snapshot: WorldSnapshot, use_native_ring: bool) -> void:
	var previous_flag := NativeFeatureFlagsScript.enable_native_snapshot_ring
	NativeFeatureFlagsScript.enable_native_snapshot_ring = use_native_ring
	snapshot_buffer.put(snapshot)
	NativeFeatureFlagsScript.enable_native_snapshot_ring = previous_flag


func _get_snapshot_with_mode(snapshot_buffer: SnapshotBuffer, tick_id: int, use_native_ring: bool) -> WorldSnapshot:
	var previous_flag := NativeFeatureFlagsScript.enable_native_snapshot_ring
	NativeFeatureFlagsScript.enable_native_snapshot_ring = use_native_ring
	var snapshot := snapshot_buffer.get_snapshot(tick_id)
	NativeFeatureFlagsScript.enable_native_snapshot_ring = previous_flag
	return snapshot


func _serialize_snapshot(snapshot: WorldSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	return {
		"tick_id": snapshot.tick_id,
		"rng_state": snapshot.rng_state,
		"players": snapshot.players,
		"bubbles": snapshot.bubbles,
		"items": snapshot.items,
		"walls": snapshot.walls,
		"match_state": snapshot.match_state,
		"mode_state": snapshot.mode_state,
		"checksum": snapshot.checksum,
	}


func _serialize_events(events: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_event in events:
		if raw_event == null:
			continue
		serialized.append({
			"event_type": int(raw_event.event_type),
			"payload": (raw_event.payload as Dictionary).duplicate(true),
		})
	return serialized


func _run_rollback_acceptance(use_native_snapshot_ring: bool) -> Dictionary:
	var previous_flag := NativeFeatureFlagsScript.enable_native_snapshot_ring
	NativeFeatureFlagsScript.enable_native_snapshot_ring = use_native_snapshot_ring

	var snapshot_service := SnapshotService.new()
	var predicted_world := _build_world(9302)
	var authoritative_world := _build_world(9302)
	var snapshot_buffer := SnapshotBuffer.new(8)
	var input_buffer := InputRingBuffer.new(8)
	var rollback_controller := RollbackController.new()

	var player := predicted_world.state.players.get_player(int(predicted_world.state.players.active_ids[0]))
	player.speed_level = 3
	predicted_world.state.players.update_player(player)
	player = authoritative_world.state.players.get_player(int(authoritative_world.state.players.active_ids[0]))
	player.speed_level = 3
	authoritative_world.state.players.update_player(player)

	for tick_id in range(1, 6):
		var frame := PlayerInputFrame.new()
		frame.peer_id = 0
		frame.tick_id = tick_id
		frame.seq = tick_id
		frame.move_x = 1 if tick_id <= 4 else 0
		input_buffer.put(frame)

		_apply_player_input(predicted_world, 0, tick_id, frame.move_x, 0)
		predicted_world.step()
		snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_world, tick_id))

		var authoritative_move_x := 0 if tick_id <= 2 else 1
		_apply_player_input(authoritative_world, 0, tick_id, authoritative_move_x, 0)
		authoritative_world.step()

	rollback_controller.configure(
		predicted_world,
		snapshot_service,
		snapshot_buffer,
		input_buffer,
		0
	)
	rollback_controller.set_predicted_until_tick(5)
	rollback_controller.on_authoritative_snapshot(snapshot_service.build_light_snapshot(authoritative_world, 2))

	var final_snapshot := snapshot_service.build_light_snapshot(predicted_world, predicted_world.state.match_state.tick)
	var result := {
		"players": final_snapshot.players,
		"rollback_count": rollback_controller.rollback_count,
		"predicted_until_tick": rollback_controller.predicted_until_tick,
	}

	rollback_controller.dispose()
	predicted_world.dispose()
	authoritative_world.dispose()
	NativeFeatureFlagsScript.enable_native_snapshot_ring = previous_flag
	return result


func _apply_player_input(world: SimWorld, player_slot: int, tick_id: int, move_x: int, move_y: int) -> void:
	var input_frame := InputFrame.new()
	input_frame.tick = tick_id
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	input_frame.set_command(player_slot, command)
	world.enqueue_input(input_frame)
