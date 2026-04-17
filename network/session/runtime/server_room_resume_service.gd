class_name ServerRoomResumeService
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func poll_idle_resume_expired(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null or room_service.room_state.match_active:
		return
	var current_time = Time.get_ticks_msec()
	var expired_peer_ids: Array[int] = []
	for member_id in room_service.room_state.member_bindings_by_member_id.keys():
		var binding = room_service.room_state.member_bindings_by_member_id[member_id]
		if binding == null:
			continue
		if String(binding.connection_state) != "disconnected":
			continue
		if int(binding.disconnect_deadline_msec) <= 0 or current_time <= int(binding.disconnect_deadline_msec):
			continue
		var peer_id = int(binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id)
		if peer_id > 0:
			expired_peer_ids.append(peer_id)
	if expired_peer_ids.is_empty():
		return
	for peer_id in expired_peer_ids:
		room_service.room_state.remove_member(peer_id)
	if room_service.room_state.members.is_empty():
		room_service.room_state.reset()
	room_service._broadcast_snapshot()


func handle_resume_request(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var ticket_validation = room_service.room_ticket_verifier.verify_resume_ticket(message) if room_service.room_ticket_verifier != null else null
	if ticket_validation == null or not bool(ticket_validation.ok):
		room_service._reject_with_ticket_error(peer_id, TransportMessageTypesScript.ROOM_RESUME_REJECTED, ticket_validation)
		return
	var ticket_claim = ticket_validation.claim

	var validation: Dictionary = room_service.room_resume_validator.validate(room_service.room_state, message, ticket_claim)
	if not bool(validation.get("ok", false)):
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": String(validation.get("error", "RECONNECT_TOKEN_INVALID")),
			"user_message": String(validation.get("user_message", "Resume request is invalid")),
		})
		return
	var binding: RoomMemberBindingState = validation.get("binding", null)
	var member_id = String(validation.get("member_id", ""))
	var reconnect_token = String(validation.get("reconnect_token", ""))
	var requested_match_id = String(validation.get("match_id", ""))
	binding.connection_state = "resuming"

	if not room_service.room_state.match_active:
		var previous_peer_id = binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id
		room_service.room_state.bind_transport_to_member(member_id, peer_id)
		binding.connection_state = "connected"
		binding.match_peer_id = peer_id
		binding.disconnect_deadline_msec = 0
		binding.device_session_id = ticket_claim.device_session_id
		binding.ticket_id = ticket_claim.ticket_id
		binding.auth_claim_version = 1
		binding.display_name_source = "profile"
		if previous_peer_id > 0 and previous_peer_id != peer_id:
			room_service.room_state.members.erase(previous_peer_id)
			room_service.room_state.ready_map.erase(previous_peer_id)
			if room_service.room_state.owner_peer_id == previous_peer_id:
				room_service.room_state.owner_peer_id = peer_id
		var profile: Dictionary = room_service.room_state.members.get(peer_id, {})
		profile["peer_id"] = peer_id
		profile["player_name"] = binding.player_name
		profile["character_id"] = binding.character_id
		profile["character_skin_id"] = binding.character_skin_id
		profile["bubble_style_id"] = binding.bubble_style_id
		profile["bubble_skin_id"] = binding.bubble_skin_id
		profile["team_id"] = binding.team_id
		profile["ready"] = binding.ready
		room_service.room_state.members[peer_id] = profile
		room_service.room_state.ready_map[peer_id] = binding.ready
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_ACCEPTED,
			"room_id": room_service.room_state.room_id,
			"owner_peer_id": room_service.room_state.owner_peer_id,
		})
		room_service._broadcast_snapshot()
		return

	room_service.resume_request_received.emit({
		"sender_peer_id": peer_id,
		"member_id": member_id,
		"reconnect_token": reconnect_token,
		"match_id": requested_match_id,
		"ticket_claim": ticket_claim.to_dict(),
	})


func send_member_session(room_service: Node, peer_id: int, binding: RoomMemberBindingState) -> void:
	if room_service == null or room_service.room_state == null or binding == null:
		return
	var token = String(binding.reconnect_token)
	var payload: Dictionary = room_service.member_session_payload_builder.build(room_service.room_state, binding, token)
	if payload.is_empty():
		return
	room_service.send_to_peer.emit(peer_id, payload)
	binding.clear_reconnect_token_plaintext()
