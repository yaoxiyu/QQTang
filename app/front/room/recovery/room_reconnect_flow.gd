class_name RoomReconnectFlow
extends RefCounted

const RoomReconnectCoordinatorScript = preload("res://app/front/room/room_reconnect_coordinator.gd")

func should_reconnect(settings_state: RefCounted) -> bool:
	if settings_state == null:
		return false
	var room_id := String(settings_state.get("reconnect_room_id")) if _has_property(settings_state, "reconnect_room_id") else ""
	var host := String(settings_state.get("reconnect_host")) if _has_property(settings_state, "reconnect_host") else ""
	var port := int(settings_state.get("reconnect_port")) if _has_property(settings_state, "reconnect_port") else 0
	return not room_id.is_empty() and not host.is_empty() and port > 0


func should_clear_pending_reconnect_ticket(pending_entry_context: RoomEntryContext, error_code: String, settings_state: RefCounted) -> bool:
	return RoomReconnectCoordinatorScript.should_clear_pending_reconnect_ticket(pending_entry_context, error_code) \
		or (should_reconnect(settings_state) and RoomReconnectCoordinatorScript.RESUME_TICKET_CLEAR_ERROR_CODES.has(error_code))


func clear_reconnect_ticket_after_rejected_resume(app_runtime: Object, error_code: String, log_sink: Object = null) -> void:
	RoomReconnectCoordinatorScript.clear_reconnect_ticket_after_rejected_resume(app_runtime, error_code, log_sink)


func apply_canonical_start_config(app_runtime: Object, config: BattleStartConfig) -> void:
	RoomReconnectCoordinatorScript.apply_canonical_start_config(app_runtime, config)


func apply_room_member_session(app_runtime: Object, payload: Dictionary, log_sink: Object = null) -> void:
	RoomReconnectCoordinatorScript.apply_room_member_session(app_runtime, payload, log_sink)


func apply_match_resume_accepted(app_runtime: Object, config: BattleStartConfig, snapshot: MatchResumeSnapshot, log_sink: Object = null) -> void:
	RoomReconnectCoordinatorScript.apply_match_resume_accepted(app_runtime, config, snapshot, log_sink)


func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for property in obj.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
