class_name SnapshotBuffer
extends RefCounted

var capacity: int = 16
var snapshots: Dictionary = {}


func _init(p_capacity: int = 16) -> void:
	capacity = max(1, p_capacity)


func put(snapshot: WorldSnapshot) -> void:
	if snapshot == null:
		return

	snapshots[snapshot.tick_id] = snapshot.duplicate_deep()

	var min_tick := snapshot.tick_id - capacity
	var to_remove: Array[int] = []
	for tick in snapshots.keys():
		if tick < min_tick:
			to_remove.append(tick)

	for tick in to_remove:
		snapshots.erase(tick)


func get_snapshot(tick_id: int) -> WorldSnapshot:
	var snapshot: WorldSnapshot = snapshots.get(tick_id, null)
	if snapshot == null:
		return null
	return snapshot.duplicate_deep()


func clear() -> void:
	snapshots.clear()
