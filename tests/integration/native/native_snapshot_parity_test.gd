extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func test_snapshot_ring_matches_dictionary_buffer_eviction_and_roundtrip() -> void:
	var snapshot_service := SnapshotService.new()
	var baseline_world := _build_world(9101)
	var native_world := _build_world(9101)
	var baseline_buffer := SnapshotBuffer.new(2)
	var native_buffer := SnapshotBuffer.new(2)

	NativeFeatureFlagsScript.enable_native_snapshot_ring = false
	_append_snapshots(baseline_world, snapshot_service, baseline_buffer)
	NativeFeatureFlagsScript.enable_native_snapshot_ring = true
	_append_snapshots(native_world, snapshot_service, native_buffer)
	NativeFeatureFlagsScript.enable_native_snapshot_ring = false

	assert_true(NativeKernelRuntimeScript.get_kernel_version() != "", "native runtime should expose kernel version")
	assert_true(baseline_buffer.get_snapshot(1) == null, "baseline snapshot buffer should evict oldest snapshot")
	assert_true(baseline_buffer.get_packed_snapshot(1).is_empty(), "baseline packed snapshot should evict oldest snapshot")
	NativeFeatureFlagsScript.enable_native_snapshot_ring = true
	assert_true(native_buffer.get_snapshot(1) == null, "native snapshot ring should evict oldest snapshot")
	assert_true(native_buffer.get_packed_snapshot(1).is_empty(), "native packed snapshot ring should evict oldest snapshot")
	assert_eq(native_buffer.get_snapshot(2).players, baseline_buffer.get_snapshot(2).players, "snapshot ring tick 2 should match baseline")
	assert_eq(native_buffer.get_snapshot(3).players, baseline_buffer.get_snapshot(3).players, "snapshot ring tick 3 should match baseline")
	assert_eq(
		_serialize_snapshot_bytes(native_buffer.get_packed_snapshot(2)),
		_serialize_snapshot_bytes(baseline_buffer.get_packed_snapshot(2)),
		"packed snapshot tick 2 should roundtrip to the same payload"
	)
	assert_true(native_buffer.has_snapshot(2), "native ring should report retained tick")
	assert_true(not native_buffer.has_snapshot(1), "native ring should report evicted tick")
	NativeFeatureFlagsScript.enable_native_snapshot_ring = false
	assert_true(native_buffer.has_snapshot(2), "native ring snapshots should remain readable after native flag rollback")
	assert_eq(
		native_buffer.get_snapshot(2).players,
		baseline_buffer.get_snapshot(2).players,
		"native ring snapshot should remain readable after native flag rollback"
	)
	assert_eq(
		_serialize_snapshot_bytes(native_buffer.get_packed_snapshot(2)),
		_serialize_snapshot_bytes(baseline_buffer.get_packed_snapshot(2)),
		"native ring packed snapshot should remain readable after native flag rollback"
	)

	baseline_world.dispose()
	native_world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	player.speed_level = 3
	world.state.players.update_player(player)
	return world


func _append_snapshots(world: SimWorld, snapshot_service: SnapshotService, snapshot_buffer: SnapshotBuffer) -> void:
	for tick_id in range(1, 4):
		var input_frame := InputFrame.new()
		input_frame.tick = tick_id
		var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
		var command := PlayerCommand.neutral()
		command.move_x = 1
		input_frame.set_command(player.player_slot, command)
		world.enqueue_input(input_frame)
		world.step()
		snapshot_buffer.put(snapshot_service.build_light_snapshot(world, tick_id))


func _serialize_snapshot_bytes(snapshot_bytes: PackedByteArray) -> Dictionary:
	var snapshot := NativeSnapshotBridge.new().unpack_snapshot(snapshot_bytes)
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
