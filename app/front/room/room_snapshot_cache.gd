class_name RoomSnapshotCache
extends RefCounted

const RoomSnapshotValidityScript = preload("res://app/front/room/room_snapshot_validity.gd")

var last_good_snapshot: RoomSnapshot = null
var last_good_room_id: String = ""
var last_good_revision: int = -1
var ignored_placeholder_count: int = 0
var stale_snapshot_count: int = 0
var battle_active: bool = false


func mark_battle_active(active: bool) -> void:
	battle_active = active


func try_accept(snapshot: RoomSnapshot, context: Dictionary = {}) -> Dictionary:
	var enriched_context := context.duplicate(true)
	enriched_context["battle_active"] = bool(enriched_context.get("battle_active", battle_active))
	var classification: Dictionary = RoomSnapshotValidityScript.classify(snapshot, enriched_context)
	if not bool(classification.get("valid", false)):
		ignored_placeholder_count += 1
		classification["accepted"] = false
		return classification
	if not RoomSnapshotValidityScript.can_apply_authoritative(snapshot, self, enriched_context):
		stale_snapshot_count += 1
		classification["accepted"] = false
		classification["reason"] = "stale_revision"
		return classification
	last_good_snapshot = snapshot.duplicate_deep() if snapshot != null else null
	last_good_room_id = String(snapshot.room_id) if snapshot != null else ""
	last_good_revision = int(snapshot.snapshot_revision) if snapshot != null else -1
	classification["accepted"] = true
	return classification


func is_last_good_snapshot(snapshot: RoomSnapshot) -> bool:
	if snapshot == null or last_good_snapshot == null:
		return false
	return String(snapshot.room_id) == last_good_room_id and int(snapshot.snapshot_revision) == last_good_revision


func get_last_good_snapshot() -> RoomSnapshot:
	return last_good_snapshot.duplicate_deep() if last_good_snapshot != null else null


func build_metrics() -> Dictionary:
	return {
		"ignored_placeholder_snapshot_count": ignored_placeholder_count,
		"stale_snapshot_count": stale_snapshot_count,
		"last_good_room_revision": last_good_revision,
		"last_good_room_id": last_good_room_id,
		"battle_active_snapshot_suppression_count": ignored_placeholder_count if battle_active else 0,
	}


func reset() -> void:
	last_good_snapshot = null
	last_good_room_id = ""
	last_good_revision = -1
	ignored_placeholder_count = 0
	stale_snapshot_count = 0
	battle_active = false
