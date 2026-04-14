class_name RoomResumeValidator
extends RefCounted


func validate(room_state: RoomServerState, message: Dictionary, ticket_claim) -> Dictionary:
	if room_state == null:
		return _reject("STATE_MISSING", "Room state is missing")

	var requested_room_id := String(message.get("room_id", "")).strip_edges()
	var member_id := String(message.get("member_id", "")).strip_edges()
	var reconnect_token := String(message.get("reconnect_token", "")).strip_edges()

	if room_state.room_id.is_empty() or requested_room_id.is_empty() or room_state.room_id != requested_room_id:
		return _reject("ROOM_NOT_FOUND", "Target room does not exist")

	var binding := room_state.get_member_binding_by_member_id(member_id)
	if binding == null:
		return _reject("MEMBER_NOT_FOUND", "Member session not found")

	if not binding.is_reconnect_token_valid(reconnect_token):
		return _reject("RECONNECT_TOKEN_INVALID", "Reconnect token is invalid")

	if ticket_claim != null:
		if binding.account_id != ticket_claim.account_id:
			return _reject("ROOM_TICKET_ACCOUNT_MISMATCH", "Room ticket account does not match member binding")
		if binding.profile_id != ticket_claim.profile_id:
			return _reject("ROOM_TICKET_PROFILE_MISMATCH", "Room ticket profile does not match member binding")

	if binding.connection_state == "disconnected" and binding.disconnect_deadline_msec > 0:
		var current_time := Time.get_ticks_msec()
		if current_time > binding.disconnect_deadline_msec:
			return _reject("RESUME_WINDOW_EXPIRED", "Resume window has expired")

	return {
		"ok": true,
		"binding": binding,
		"member_id": member_id,
		"reconnect_token": reconnect_token,
		"match_id": String(message.get("match_id", "")).strip_edges(),
	}


func _reject(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"user_message": user_message,
	}
