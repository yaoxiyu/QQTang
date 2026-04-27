class_name RoomReadyCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


func can_toggle_ready(app_runtime: Object) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return RoomErrorMapperScript.to_front_error("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_READY_LOCKED", "Match room readiness is automatic")
	return {"ok": true}


func toggle_ready(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	var ready_check := can_toggle_ready(app_runtime)
	if not bool(ready_check.get("ok", false)):
		return ready_check
	var result: Dictionary = app_runtime.room_session_controller.request_toggle_ready(int(app_runtime.local_peer_id))
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_toggle_ready()
	return result
