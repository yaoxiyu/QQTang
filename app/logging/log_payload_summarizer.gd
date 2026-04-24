class_name LogPayloadSummarizer
extends RefCounted


static func summarize_room_snapshot(snapshot) -> Dictionary:
	if snapshot == null:
		return {}
	if snapshot is Dictionary:
		var dict := snapshot as Dictionary
		return {
			"room_id": String(dict.get("room_id", "")),
			"phase": String(dict.get("room_phase", dict.get("phase", ""))),
			"revision": int(dict.get("snapshot_revision", dict.get("revision", 0))),
			"member_count": (dict.get("members", []) as Array).size() if dict.get("members", []) is Array else 0,
			"has_assignment": not String(dict.get("current_assignment_id", "")).is_empty(),
		}
	return {
		"room_id": String(snapshot.get("room_id")) if _has_property(snapshot, "room_id") else "",
		"phase": String(snapshot.get("room_phase")) if _has_property(snapshot, "room_phase") else "",
		"revision": int(snapshot.get("snapshot_revision")) if _has_property(snapshot, "snapshot_revision") else 0,
		"member_count": snapshot.get("members").size() if _has_property(snapshot, "members") and snapshot.get("members") is Array else 0,
		"has_assignment": not String(snapshot.get("current_assignment_id")).is_empty() if _has_property(snapshot, "current_assignment_id") else false,
	}


static func summarize_battle_snapshot(snapshot) -> Dictionary:
	if snapshot == null:
		return {}
	if snapshot is Dictionary:
		var dict := snapshot as Dictionary
		return {
			"tick_id": int(dict.get("tick_id", dict.get("tick", 0))),
			"checksum": int(dict.get("checksum", 0)),
			"player_count": (dict.get("players", []) as Array).size() if dict.get("players", []) is Array else 0,
			"bubble_count": (dict.get("bubbles", []) as Array).size() if dict.get("bubbles", []) is Array else 0,
		}
	return {
		"tick_id": int(snapshot.get("tick_id")) if _has_property(snapshot, "tick_id") else 0,
		"checksum": int(snapshot.get("checksum")) if _has_property(snapshot, "checksum") else 0,
		"player_count": snapshot.get("players").size() if _has_property(snapshot, "players") and snapshot.get("players") is Array else 0,
		"bubble_count": snapshot.get("bubbles").size() if _has_property(snapshot, "bubbles") and snapshot.get("bubbles") is Array else 0,
	}


static func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for property in obj.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
