class_name RoomLeaveCommand
extends RefCounted

const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


func can_leave(app_runtime: Object) -> Dictionary:
	if app_runtime == null:
		return RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING", "App runtime is not configured")
	return {"ok": true}


func should_cancel_queue_on_leave(app_runtime: Object, room_client_gateway: RefCounted, can_cancel_current_queue: bool) -> bool:
	return room_client_gateway != null \
		and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime) \
		and RoomUseCaseRuntimeStateScript.is_match_room(app_runtime) \
		and can_cancel_current_queue \
		and room_client_gateway.has_method("request_cancel_match_queue")


func request_gateway_leave(app_runtime: Object, room_client_gateway: RefCounted, can_cancel_current_queue: bool) -> void:
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return
	if not _is_transport_connected(room_client_gateway):
		return
	if should_cancel_queue_on_leave(app_runtime, room_client_gateway, can_cancel_current_queue):
		room_client_gateway.request_cancel_match_queue()
	if room_client_gateway.has_method("request_leave_room_and_disconnect"):
		room_client_gateway.request_leave_room_and_disconnect()
	else:
		room_client_gateway.request_leave_room()


func leave_room(app_runtime: Object, room_client_gateway: RefCounted, can_cancel_current_queue: bool = false) -> Dictionary:
	var leave_check: Dictionary = can_leave(app_runtime)
	if not bool(leave_check.get("ok", false)):
		return leave_check
	_apply_match_room_return_policy(app_runtime)
	request_gateway_leave(app_runtime, room_client_gateway, can_cancel_current_queue)
	var room_controller: Node = app_runtime.room_session_controller
	if room_controller != null and room_controller.has_method("reset_room_state"):
		room_controller.reset_room_state()
	if app_runtime.front_settings_state != null and app_runtime.front_settings_state.has_method("clear_reconnect_ticket"):
		app_runtime.front_settings_state.clear_reconnect_ticket()
		if app_runtime.front_settings_repository != null and app_runtime.front_settings_repository.has_method("save_settings"):
			app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)
	app_runtime.current_room_snapshot = null
	app_runtime.current_room_entry_context = null
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_lobby"):
		app_runtime.front_flow.enter_lobby()
	return {"ok": true, "error_code": "", "user_message": ""}


func _apply_match_room_return_policy(app_runtime: Object) -> void:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return
	var return_policy := ""
	if app_runtime.current_room_snapshot != null:
		return_policy = String(app_runtime.current_room_snapshot.room_return_policy)
	if return_policy == "return_to_source_room":
		return
	if app_runtime.current_room_entry_context != null:
		app_runtime.current_room_entry_context.return_target = FrontReturnTargetScript.LOBBY
		app_runtime.current_room_entry_context.return_to_lobby_after_settlement = true


func _is_transport_connected(room_client_gateway: RefCounted) -> bool:
	if room_client_gateway == null:
		return false
	if not room_client_gateway.has_method("is_transport_connected"):
		return true
	return bool(room_client_gateway.is_transport_connected())
