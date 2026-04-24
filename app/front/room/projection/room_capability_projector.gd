class_name RoomCapabilityProjector
extends RefCounted


func project(snapshot: Dictionary) -> Dictionary:
	var capabilities: Dictionary = snapshot.get("capabilities", {}) if snapshot.has("capabilities") else {}
	return capabilities.duplicate(true)
