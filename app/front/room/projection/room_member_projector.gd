class_name RoomMemberProjector
extends RefCounted


func project(snapshot: Dictionary) -> Array:
	var members: Array = snapshot.get("members", []) if snapshot.has("members") else []
	return members.duplicate(true)
