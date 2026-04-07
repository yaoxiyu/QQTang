extends Node


func _ready() -> void:
	var world := _build_world(4242)
	var snapshot_service := SnapshotService.new()
	var input_buffer := InputRingBuffer.new(16)
	var rollback := RollbackController.new()
	add_child(rollback)
	rollback.configure(world, snapshot_service, SnapshotBuffer.new(), input_buffer, 0, 16)

	var local_snapshot := snapshot_service.build_light_snapshot(world, 0)
	rollback.snapshot_buffer.put(local_snapshot)
	rollback.set_predicted_until_tick(0)

	var authoritative_snapshot := local_snapshot.duplicate_deep()
	for index in range(authoritative_snapshot.players.size()):
		var entry := authoritative_snapshot.players[index]
		if int(entry.get("player_slot", -1)) != 1:
			continue
		entry["cell_x"] = int(entry.get("cell_x", 0)) + 1
		authoritative_snapshot.players[index] = entry
		break

	var changed := rollback.on_authoritative_snapshot(authoritative_snapshot)
	_assert(not changed, "remote-only player drift should not trigger local rollback")
	_assert(rollback.rollback_count == 0, "remote-only player drift should keep rollback_count at 0")
	_assert(rollback.force_resync_count == 0, "remote-only player drift should not force resync")

	rollback.dispose()
	rollback.queue_free()
	world.dispose()

	print("test_remote_player_diff_no_local_rollback: PASS")


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_remote_player_diff_no_local_rollback: FAIL - %s" % message)
