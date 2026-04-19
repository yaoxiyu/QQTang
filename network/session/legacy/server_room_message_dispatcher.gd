class_name ServerRoomMessageDispatcher
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func dispatch_message(room_service: Node, message: Dictionary) -> void:
	if room_service == null:
		return
	var message_type = String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.ROOM_CREATE_REQUEST:
			room_service._handle_create_request(message)
		TransportMessageTypesScript.ROOM_JOIN_REQUEST:
			room_service._handle_join_request(message)
		TransportMessageTypesScript.ROOM_UPDATE_PROFILE:
			room_service._handle_update_profile(message)
		TransportMessageTypesScript.ROOM_UPDATE_SELECTION:
			room_service._handle_update_selection(message)
		TransportMessageTypesScript.ROOM_UPDATE_MATCH_ROOM_CONFIG:
			room_service._handle_update_match_room_config(message)
		TransportMessageTypesScript.ROOM_ENTER_MATCH_QUEUE:
			room_service._handle_enter_match_queue(message)
		TransportMessageTypesScript.ROOM_CANCEL_MATCH_QUEUE:
			room_service._handle_cancel_match_queue(message)
		TransportMessageTypesScript.ROOM_BATTLE_RETURN:
			room_service._handle_battle_return(message)
		TransportMessageTypesScript.ROOM_TOGGLE_READY:
			room_service._handle_toggle_ready(message)
		TransportMessageTypesScript.ROOM_START_REQUEST:
			room_service._handle_start_request(message)
		TransportMessageTypesScript.ROOM_LEAVE:
			room_service._handle_leave_request(message)
		TransportMessageTypesScript.ROOM_REMATCH_REQUEST:
			room_service._handle_rematch_request(message)
		TransportMessageTypesScript.ROOM_RESUME_REQUEST:
			room_service._handle_resume_request(message)
		_:
			pass


func broadcast_snapshot(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var snapshot = room_service.room_state.build_snapshot()
	room_service.room_snapshot_updated.emit(snapshot)
	room_service.broadcast_message.emit({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	})


func broadcast_match_queue_status(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.broadcast_message.emit({
		"message_type": TransportMessageTypesScript.ROOM_MATCH_QUEUE_STATUS,
		"room_id": room_service.room_state.room_id,
		"queue_type": room_service.room_state.queue_type,
		"match_format_id": room_service.room_state.match_format_id,
		"selected_match_mode_ids": room_service.room_state.selected_match_mode_ids.duplicate(),
		"required_party_size": room_service.room_state.required_party_size,
		"queue_state": room_service.room_state.room_queue_state,
		"queue_entry_id": room_service.room_state.room_queue_entry_id,
		"queue_status_text": room_service.room_state.room_queue_status_text,
		"error_code": room_service.room_state.room_queue_error_code,
		"user_message": room_service.room_state.room_queue_error_message,
	})


func send_match_queue_status(room_service: Node, peer_id: int, error_code: String = "", user_message: String = "") -> void:
	if room_service == null or room_service.room_state == null:
		return
	if not error_code.is_empty():
		room_service.room_state.room_queue_error_code = error_code
		room_service.room_state.room_queue_error_message = user_message
	room_service.send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_MATCH_QUEUE_STATUS,
		"room_id": room_service.room_state.room_id,
		"queue_type": room_service.room_state.queue_type,
		"match_format_id": room_service.room_state.match_format_id,
		"selected_match_mode_ids": room_service.room_state.selected_match_mode_ids.duplicate(),
		"required_party_size": room_service.room_state.required_party_size,
		"queue_state": room_service.room_state.room_queue_state,
		"queue_entry_id": room_service.room_state.room_queue_entry_id,
		"queue_status_text": room_service.room_state.room_queue_status_text,
		"error_code": error_code,
		"user_message": user_message,
	})


func reject_with_ticket_error(room_service: Node, peer_id: int, message_type: String, validation_result) -> void:
	if room_service == null:
		return
	room_service._log_room_service("ticket_validation_rejected", {
		"peer_id": peer_id,
		"message_type": message_type,
		"error_code": String(validation_result.error_code if validation_result != null else "ROOM_TICKET_INVALID"),
		"user_message": String(validation_result.user_message if validation_result != null else "Room ticket validation failed"),
	})
	room_service.send_to_peer.emit(peer_id, {
		"message_type": message_type,
		"error": String(validation_result.error_code if validation_result != null else "ROOM_TICKET_INVALID"),
		"user_message": String(validation_result.user_message if validation_result != null else "Room ticket validation failed"),
	})
