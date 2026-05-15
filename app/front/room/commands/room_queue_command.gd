class_name RoomQueueCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


func can_enter_queue(app_runtime: Object, room_client_gateway: RefCounted, room_id: String) -> Dictionary:
	if app_runtime == null:
		return RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING")
	if room_client_gateway == null:
		return RoomErrorMapperScript.to_front_error("ROOM_GATEWAY_MISSING")
	if String(room_id).strip_edges().is_empty():
		return RoomErrorMapperScript.to_front_error("ROOM_ID_MISSING", "房间 ID 为空")
	return {"ok": true}


func can_enter_match_queue(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("NOT_MATCH_ROOM", "Queue can only be entered from match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_enter_match_queue"):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	return {"ok": true}


func request_enter_match_queue(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	var queue_check := can_enter_match_queue(app_runtime, room_client_gateway)
	if not bool(queue_check.get("ok", false)):
		return queue_check
	if not _is_transport_connected(room_client_gateway):
		return RoomErrorMapperScript.to_front_error("ROOM_NOT_CONNECTED", "尚未连接房间")
	room_client_gateway.request_enter_match_queue()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func request_cancel_match_queue(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("NOT_MATCH_ROOM", "Queue can only be cancelled from match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_cancel_match_queue"):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	if not _is_transport_connected(room_client_gateway):
		return RoomErrorMapperScript.to_front_error("ROOM_NOT_CONNECTED", "尚未连接房间")
	room_client_gateway.request_cancel_match_queue()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func acknowledge_enter_match_queue_pending(runtime_state: RoomUseCaseRuntimeState, snapshot: RoomSnapshot) -> String:
	if runtime_state == null or not runtime_state.enter_match_queue_pending or snapshot == null:
		return ""
	var snapshot_room_id := String(snapshot.room_id)
	if not runtime_state.enter_match_queue_pending_room_id.is_empty() and not snapshot_room_id.is_empty() and snapshot_room_id != runtime_state.enter_match_queue_pending_room_id:
		return "room_changed"
	if _is_queue_enter_acknowledged(snapshot):
		return "queue_state_acknowledged"
	return ""


func _is_queue_enter_acknowledged(snapshot: RoomSnapshot) -> bool:
	if snapshot == null:
		return false
	var active_states := [
		"queued",
		"assignment_pending",
		"allocating_battle",
	]
	var queue_phase := String(snapshot.queue_phase)
	if active_states.has(queue_phase):
		return true
	if bool(snapshot.can_cancel_queue):
		return true
	return false


func _is_transport_connected(room_client_gateway: RefCounted) -> bool:
	if room_client_gateway == null:
		return false
	if not room_client_gateway.has_method("is_transport_connected"):
		return true
	return bool(room_client_gateway.is_transport_connected())
