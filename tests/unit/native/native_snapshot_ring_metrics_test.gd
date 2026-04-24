extends "res://tests/gut/base/qqt_unit_test.gd"


func test_native_snapshot_ring_metrics_track_limits_and_access() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeSnapshotRing"), "native snapshot ring class should be available")
	if not ClassDB.can_instantiate("QQTNativeSnapshotRing"):
		return

	var ring = ClassDB.instantiate("QQTNativeSnapshotRing")
	ring.configure_with_limits(2, 1024)
	var metrics: Dictionary = ring.get_metrics()
	assert_eq(int(metrics.get("capacity", 0)), 2, "capacity metric should match configured capacity")
	assert_eq(int(metrics.get("max_snapshot_bytes", 0)), 1024, "max bytes metric should match configured limit")

	var payload := PackedByteArray([1, 2, 3])
	ring.put_snapshot(1, payload)
	ring.get_snapshot(1)
	ring.get_snapshot(999)

	metrics = ring.get_metrics()
	assert_eq(int(metrics.get("put_count", 0)), 1, "put_count should increment")
	assert_eq(int(metrics.get("get_count", 0)), 2, "get_count should increment")
	assert_eq(int(metrics.get("hit_count", 0)), 1, "hit_count should increment")
	assert_eq(int(metrics.get("miss_count", 0)), 1, "miss_count should increment")
	assert_eq(int(metrics.get("total_bytes_written", 0)), payload.size(), "total bytes should track payload size")
	assert_eq(int(metrics.get("current_bytes_stored", 0)), payload.size(), "current bytes should track stored slot bytes")
	assert_eq(int(metrics.get("max_bytes_stored", 0)), payload.size(), "max bytes should track peak stored slot bytes")


func test_native_snapshot_ring_metrics_track_overwrite_and_rejection() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeSnapshotRing"), "native snapshot ring class should be available")
	if not ClassDB.can_instantiate("QQTNativeSnapshotRing"):
		return

	var ring = ClassDB.instantiate("QQTNativeSnapshotRing")
	ring.configure_with_limits(1, 2)
	ring.put_snapshot(1, PackedByteArray([1]))
	ring.put_snapshot(2, PackedByteArray([2]))
	ring.put_snapshot(3, PackedByteArray([1, 2, 3]))

	var metrics: Dictionary = ring.get_metrics()
	assert_eq(int(metrics.get("overwrite_count", 0)), 1, "capacity one should overwrite old tick")
	assert_eq(int(metrics.get("rejected_too_large_count", 0)), 1, "oversized payload should be rejected")
	assert_eq(int(metrics.get("current_bytes_stored", 0)), 1, "overwrite should replace stored byte accounting")
	assert_eq(int(metrics.get("max_bytes_stored", 0)), 1, "rejected payload should not raise stored byte peak")


func test_snapshot_buffer_configures_native_ring_limit_from_feature_flag() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeSnapshotRing"), "native snapshot ring class should be available")
	if not ClassDB.can_instantiate("QQTNativeSnapshotRing"):
		return

	var previous_limit: int = NativeFeatureFlags.native_snapshot_ring_max_snapshot_bytes
	var previous_enabled: bool = NativeFeatureFlags.enable_native_snapshot_ring
	NativeFeatureFlags.enable_native_snapshot_ring = true
	NativeFeatureFlags.native_snapshot_ring_max_snapshot_bytes = 2048
	var buffer := SnapshotBuffer.new(2)
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = 1
	buffer.put(snapshot)
	var metrics := buffer.get_native_snapshot_ring_metrics()
	NativeFeatureFlags.native_snapshot_ring_max_snapshot_bytes = previous_limit
	NativeFeatureFlags.enable_native_snapshot_ring = previous_enabled

	if metrics.is_empty():
		return
	assert_eq(int(metrics.get("max_snapshot_bytes", 0)), 2048, "snapshot buffer should propagate native ring max byte limit")
