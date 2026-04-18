class_name RoomUseCaseRuntimeState
extends RefCounted

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


static func is_online_room(app_runtime: Node) -> bool:
	if app_runtime == null:
		return false
	if app_runtime.current_room_entry_context != null and String(app_runtime.current_room_entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER:
		return true
	if app_runtime.current_room_snapshot != null and String(app_runtime.current_room_snapshot.topology) == FrontTopologyScript.DEDICATED_SERVER:
		return true
	if app_runtime.room_session_controller != null and app_runtime.room_session_controller.room_runtime_context != null:
		return String(app_runtime.room_session_controller.room_runtime_context.topology) == FrontTopologyScript.DEDICATED_SERVER
	return false


static func is_matchmade_room(app_runtime: Node, entry_context: RoomEntryContext = null) -> bool:
	var target := entry_context
	if target == null and app_runtime != null:
		target = app_runtime.current_room_entry_context
	if target != null and String(target.room_kind) == FrontRoomKindScript.MATCHMADE_ROOM:
		return true
	if app_runtime != null and app_runtime.current_room_snapshot != null:
		return String(app_runtime.current_room_snapshot.room_kind) == FrontRoomKindScript.MATCHMADE_ROOM
	return false


static func is_match_room(app_runtime: Node, entry_context: RoomEntryContext = null) -> bool:
	var target := entry_context
	if target == null and app_runtime != null:
		target = app_runtime.current_room_entry_context
	if target != null and FrontRoomKindScript.is_match_room(String(target.room_kind)):
		return true
	if app_runtime != null and app_runtime.current_room_snapshot != null:
		return FrontRoomKindScript.is_match_room(String(app_runtime.current_room_snapshot.room_kind))
	return false


static func has_source_room_return_policy(app_runtime: Node, _entry_context: RoomEntryContext = null) -> bool:
	if app_runtime != null and app_runtime.current_room_snapshot != null:
		if String(app_runtime.current_room_snapshot.room_return_policy) == "return_to_source_room":
			return true
	return false


static func get_current_room_queue_state(app_runtime: Node) -> String:
	if app_runtime == null or app_runtime.current_room_snapshot == null:
		return ""
	for property in app_runtime.current_room_snapshot.get_property_list():
		if String(property.get("name", "")) == "room_queue_state":
			return String(app_runtime.current_room_snapshot.get("room_queue_state"))
	return ""


static func build_entry_context_context(entry_context: RoomEntryContext) -> Dictionary:
	if entry_context == null:
		return {}
	return {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"topology": String(entry_context.topology),
		"server_host": String(entry_context.server_host),
		"server_port": int(entry_context.server_port),
		"target_room_id": String(entry_context.target_room_id),
	}


static func build_snapshot_context(snapshot: RoomSnapshot, pending_connection_context: Dictionary) -> Dictionary:
	var context := pending_connection_context.duplicate(true)
	context["snapshot_room_id"] = String(snapshot.room_id) if snapshot != null else ""
	context["snapshot_topology"] = String(snapshot.topology) if snapshot != null else ""
	context["snapshot_member_count"] = snapshot.members.size() if snapshot != null else -1
	return context
