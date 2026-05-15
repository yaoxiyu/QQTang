class_name RoomSelectionCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


func can_update_selection(app_runtime: Object) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return RoomErrorMapperScript.to_front_error("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_SELECTION_FORBIDDEN", "Match room selection is controlled by match format and mode pool")
	return {"ok": true}


func update_selection(app_runtime: Object, room_client_gateway: RefCounted, map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	var selection_check := can_update_selection(app_runtime)
	if not bool(selection_check.get("ok", false)):
		return selection_check
	if room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime) and not _is_transport_connected(room_client_gateway):
		return RoomErrorMapperScript.to_front_error("ROOM_NOT_CONNECTED", "尚未连接房间")
	var result: Dictionary = app_runtime.room_session_controller.request_update_selection(
		int(app_runtime.local_peer_id),
		map_id,
		rule_id,
		mode_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_update_selection(map_id, rule_id, mode_id)
	return result


func _is_transport_connected(room_client_gateway: RefCounted) -> bool:
	if room_client_gateway == null:
		return false
	if not room_client_gateway.has_method("is_transport_connected"):
		return true
	return bool(room_client_gateway.is_transport_connected())
