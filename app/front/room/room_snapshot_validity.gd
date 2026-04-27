class_name RoomSnapshotValidity
extends RefCounted

const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


static func classify(snapshot: RoomSnapshot, context: Dictionary = {}) -> Dictionary:
	if snapshot == null:
		return _result(false, "invalid_null", snapshot, context)
	var room_id := String(snapshot.room_id)
	var revision := int(snapshot.snapshot_revision)
	var phase := String(snapshot.room_phase)
	var topology := String(snapshot.topology)
	if topology.is_empty():
		topology = String(context.get("topology", ""))
	var dedicated := topology == FrontTopologyScript.DEDICATED_SERVER
	if room_id.is_empty() and revision <= 0 and snapshot.members.is_empty() and (phase.is_empty() or phase == "idle"):
		return _result(false, "placeholder_empty", snapshot, context)
	if not room_id.is_empty() and revision <= 0 and snapshot.members.is_empty() and phase.is_empty() and not _is_explicitly_returning_or_closed(snapshot, context):
		return _result(false, "placeholder_empty_room_state", snapshot, context)
	if dedicated and room_id.is_empty():
		return _result(false, "placeholder_missing_room_id", snapshot, context)
	if dedicated and snapshot.members.is_empty() and not _is_explicitly_returning_or_closed(snapshot, context):
		return _result(false, "placeholder_empty_members", snapshot, context)
	return _result(true, "valid", snapshot, context)


static func is_placeholder(snapshot: RoomSnapshot) -> bool:
	return not bool(classify(snapshot).get("valid", false))


static func can_apply_authoritative(snapshot: RoomSnapshot, cache: RefCounted, context: Dictionary = {}) -> bool:
	var classification := classify(snapshot, context)
	if not bool(classification.get("valid", false)):
		return false
	if cache == null:
		return true
	if cache.has_method("is_last_good_snapshot") and bool(cache.call("is_last_good_snapshot", snapshot)):
		return true
	var room_id := String(snapshot.room_id)
	var revision := int(snapshot.snapshot_revision)
	if not room_id.is_empty() and room_id == String(cache.get("last_good_room_id")) and revision <= int(cache.get("last_good_revision")):
		return false
	return true


static func build_log_context(snapshot: RoomSnapshot, context: Dictionary = {}) -> Dictionary:
	var result := context.duplicate(true)
	result["snapshot_room_id"] = String(snapshot.room_id) if snapshot != null else ""
	result["snapshot_revision"] = int(snapshot.snapshot_revision) if snapshot != null else -1
	result["snapshot_member_count"] = snapshot.members.size() if snapshot != null else -1
	result["snapshot_phase"] = String(snapshot.room_phase) if snapshot != null else ""
	result["snapshot_topology"] = String(snapshot.topology) if snapshot != null else ""
	return result


static func _result(valid: bool, reason: String, snapshot: RoomSnapshot, context: Dictionary) -> Dictionary:
	var result := build_log_context(snapshot, context)
	result["valid"] = valid
	result["reason"] = reason
	return result


static func _is_explicitly_returning_or_closed(snapshot: RoomSnapshot, context: Dictionary) -> bool:
	if bool(context.get("allow_empty_members", false)):
		return true
	var phase := String(snapshot.room_phase)
	var lifecycle := String(snapshot.room_lifecycle_state)
	return phase == "returning_to_room" or phase == "closed" or lifecycle == "closed"
