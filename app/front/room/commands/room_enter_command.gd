class_name RoomEnterCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


func can_enter(app_runtime: Object, entry_context: RoomEntryContext) -> Dictionary:
	if app_runtime == null:
		return RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING")
	if entry_context == null:
		return RoomErrorMapperScript.to_front_error("ROOM_ENTRY_CONTEXT_MISSING", "房间入口上下文为空")
	return {"ok": true}


func should_use_online_dedicated_room(entry_context: RoomEntryContext) -> bool:
	if entry_context == null:
		return false
	return String(entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER \
		and String(entry_context.room_kind) != FrontRoomKindScript.PRACTICE
