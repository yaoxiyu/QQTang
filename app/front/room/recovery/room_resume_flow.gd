class_name RoomResumeFlow
extends RefCounted


func build_resume_context(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	return {
		"room_id": String(snapshot.get("room_id", "")),
		"phase": String(snapshot.get("phase", "")),
		"revision": int(snapshot.get("revision", 0)),
		"match_id": String(snapshot.get("match_id", "")),
	}
