class_name DivergenceLogger
extends RefCounted

var last_divergence_tick: int = -1
var records: Array[Dictionary] = []


func compare(server_tick: int, server_hash: int, local_hash: int) -> bool:
	if server_hash == local_hash:
		return true

	last_divergence_tick = server_tick
	var record := {
		"tick": server_tick,
		"server_hash": server_hash,
		"local_hash": local_hash
	}
	records.append(record)
	push_warning("desync at tick=%s server=%s local=%s" % [server_tick, server_hash, local_hash])
	return false


func compare_snapshots(server_snapshot: WorldSnapshot, local_snapshot: WorldSnapshot, snapshot_service: SnapshotService = null) -> Dictionary:
	var report := {
		"match": true,
		"tick": -1,
		"server_hash": 0,
		"local_hash": 0
	}

	if server_snapshot == null or local_snapshot == null:
		report["match"] = false
		report["reason"] = "missing_snapshot"
		return report

	report["tick"] = server_snapshot.tick_id
	report["server_hash"] = server_snapshot.checksum
	report["local_hash"] = local_snapshot.checksum

	if server_snapshot.checksum == local_snapshot.checksum:
		return report

	report["match"] = false
	last_divergence_tick = server_snapshot.tick_id
	if snapshot_service != null:
		report["diff"] = snapshot_service.build_diff(server_snapshot, local_snapshot)
	records.append(report)
	return report


func clear() -> void:
	last_divergence_tick = -1
	records.clear()
