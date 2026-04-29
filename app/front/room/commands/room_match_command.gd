class_name RoomMatchCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


func start_match(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return RoomErrorMapperScript.to_front_error("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_START_FORBIDDEN", "Match rooms must enter matchmaking queue")
	if room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		var capability_check := _can_start_online_manual_room(app_runtime)
		if not bool(capability_check.get("ok", false)):
			return capability_check
		room_client_gateway.request_start_match()
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}
	var result: Dictionary = app_runtime.room_session_controller.request_begin_match(int(app_runtime.local_peer_id))
	if bool(result.get("ok", false)) and app_runtime.front_flow != null and app_runtime.front_flow.has_method("request_start_match"):
		app_runtime.front_flow.request_start_match()
	return result


func update_match_room_config(app_runtime: Object, room_client_gateway: RefCounted, match_format_id: String, selected_mode_ids: Array[String]) -> Dictionary:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("NOT_MATCH_ROOM", "Match room config can only be updated in match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_update_match_room_config"):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	room_client_gateway.request_update_match_room_config(match_format_id, selected_mode_ids)
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func request_rematch(app_runtime: Object, room_client_gateway: RefCounted) -> Dictionary:
	if app_runtime == null or room_client_gateway == null:
		return RoomErrorMapperScript.to_front_error("ROOM_USE_CASE_MISSING", "App runtime or gateway is not configured")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("MATCH_ROOM_REMATCH_FORBIDDEN", "Match rooms return to lobby after settlement")
	if not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return RoomErrorMapperScript.to_front_error("NOT_ONLINE_ROOM", "Rematch is only supported in online rooms")
	room_client_gateway.request_rematch()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func _can_start_online_manual_room(app_runtime: Object) -> Dictionary:
	if app_runtime == null or app_runtime.current_room_snapshot == null:
		return RoomErrorMapperScript.to_front_error("ROOM_SNAPSHOT_MISSING", "Room state is not ready")
	var snapshot: RoomSnapshot = app_runtime.current_room_snapshot
	var local_is_owner := false
	for member in snapshot.members:
		if member != null and member.is_local_player:
			local_is_owner = member.is_owner
			break
	if not local_is_owner:
		return RoomErrorMapperScript.to_front_error("ROOM_START_FORBIDDEN", "Only the host can start the match")
	if not bool(snapshot.can_start_manual_battle):
		return RoomErrorMapperScript.to_front_error("ROOM_MEMBER_NOT_READY", "All non-host players must be ready before starting")
	return {"ok": true}
