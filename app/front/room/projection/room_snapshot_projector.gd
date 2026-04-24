class_name RoomSnapshotProjector
extends RefCounted


func build_view_state(snapshot: Dictionary, previous_view_state: Dictionary = {}) -> Dictionary:
	var view_state := previous_view_state.duplicate(true)
	if snapshot.is_empty():
		return view_state
	view_state["room_id"] = String(snapshot.get("room_id", view_state.get("room_id", "")))
	view_state["phase"] = String(snapshot.get("phase", view_state.get("phase", "")))
	view_state["revision"] = int(snapshot.get("revision", view_state.get("revision", 0)))
	view_state["members"] = snapshot.get("members", [])
	view_state["capabilities"] = snapshot.get("capabilities", {})
	return view_state
