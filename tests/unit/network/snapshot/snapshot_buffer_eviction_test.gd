extends Node


func _ready() -> void:
	var snapshot_buffer := SnapshotBuffer.new(3)
	for tick_id in [1, 2, 3, 4, 5]:
		var snapshot := WorldSnapshot.new()
		snapshot.tick_id = tick_id
		snapshot.checksum = tick_id * 100
		snapshot_buffer.put(snapshot)

	_assert(snapshot_buffer.get_snapshot(1) == null, "oldest snapshot should be evicted when capacity is exceeded")
	_assert(snapshot_buffer.get_snapshot(2) != null, "snapshot at capacity boundary should be retained")
	_assert(snapshot_buffer.get_snapshot(3) != null, "recent snapshot should be retained")
	_assert(snapshot_buffer.get_snapshot(5) != null, "latest snapshot should be retained")

	print("test_snapshot_buffer_eviction: PASS")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_snapshot_buffer_eviction: FAIL - %s" % message)
