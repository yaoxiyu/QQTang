extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_rollback_controller_exposes_public_snapshot_diff_and_native_shadow_metrics() -> void:
	var rollback := RollbackController.new()
	rollback.local_peer_id = 1
	var local_snapshot := _world_snapshot(1, 1)
	var authority_snapshot := _world_snapshot(1, 2)

	var diff := rollback.describe_snapshot_diff(local_snapshot, authority_snapshot)

	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "local_player")
	var metrics := rollback.get_native_rollback_shadow_metrics()
	assert_true(metrics.has("snapshot_diff"))


func test_rollback_controller_native_execute_planner_preserves_force_resync_decision() -> void:
	var old_diff_execute := NativeFeatureFlagsScript.enable_native_snapshot_diff_execute
	var old_planner_execute := NativeFeatureFlagsScript.enable_native_rollback_planner_execute
	NativeFeatureFlagsScript.enable_native_snapshot_diff_execute = true
	NativeFeatureFlagsScript.enable_native_rollback_planner_execute = true

	var rollback := RollbackController.new()
	rollback.local_peer_id = 1
	rollback.predicted_until_tick = 3
	var local_snapshot := _world_snapshot(1, 1)
	var authority_snapshot := _world_snapshot(1, 2)
	authority_snapshot.rng_state = 123
	local_snapshot.rng_state = 456

	var diff := rollback.describe_snapshot_diff(local_snapshot, authority_snapshot)
	var plan := rollback._plan_rollback(authority_snapshot, local_snapshot, diff)

	assert_false(bool(diff.get("equal", true)))
	assert_eq(int(plan.get("decision", -1)), RollbackController.PLAN_FORCE_RESYNC)

	NativeFeatureFlagsScript.enable_native_snapshot_diff_execute = old_diff_execute
	NativeFeatureFlagsScript.enable_native_rollback_planner_execute = old_planner_execute


func _world_snapshot(tick: int, cell_x: int) -> WorldSnapshot:
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = tick
	snapshot.players = [{
		"player_slot": 1,
		"cell_x": cell_x,
		"cell_y": 1,
	}]
	snapshot.bubbles = []
	snapshot.items = []
	return snapshot
