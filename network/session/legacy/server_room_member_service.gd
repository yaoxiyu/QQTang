class_name ServerRoomMemberService
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomSelectionPolicyScript = preload("res://network/session/runtime/room_selection_policy.gd")


func handle_peer_disconnected(room_service: Node, peer_id: int) -> void:
	if room_service == null or room_service.room_state == null:
		return
	if room_service.room_state.is_match_room() and room_service.room_state.room_queue_state == "queueing":
		room_service._cancel_party_queue_backend()
		room_service._cancel_match_queue_locally("member_disconnected")
	var binding = room_service.room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		room_service.room_state.mark_member_disconnected_by_transport_peer(
			peer_id,
			Time.get_ticks_msec() + 20000,
			""
		)
		room_service._broadcast_snapshot()
		return
	if not room_service.room_state.members.has(peer_id):
		return
	room_service.room_state.remove_member(peer_id)
	if room_service.room_state.members.is_empty():
		room_service.room_state.reset()
	room_service._broadcast_snapshot()


func handle_update_profile(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	var loadout_result = RoomSelectionPolicyScript.resolve_request_loadout(message)
	var team_id = int(message.get("team_id", 1))
	if room_service.room_state.match_active:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_FORBIDDEN",
			"user_message": "Profile cannot be changed during an active match",
		})
		return
	if not bool(loadout_result.get("ok", false)):
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": String(loadout_result.get("error", "ROOM_MEMBER_PROFILE_INVALID")),
			"user_message": String(loadout_result.get("user_message", "Character selection is invalid")),
		})
		return
	if room_service.room_state.is_matchmade_room:
		var current_profile: Dictionary = room_service.room_state.members.get(peer_id, {})
		team_id = int(current_profile.get("team_id", team_id))
	if team_id < 1 or team_id > room_service.room_state.max_players:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Team selection is invalid",
		})
		return
	if bool(room_service.room_state.ready_map.get(peer_id, false)):
		var profile: Dictionary = room_service.room_state.members.get(peer_id, {})
		var current_team_id = int(profile.get("team_id", team_id))
		if team_id != current_team_id:
			room_service.send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
				"error": "ROOM_MEMBER_PROFILE_FORBIDDEN",
				"user_message": "Team cannot be changed after ready",
			})
			return
	room_service.room_state.update_profile(
		peer_id,
		String(message.get("player_name", "Player%d" % peer_id)),
		String(loadout_result.get("character_id", "")),
		String(loadout_result.get("character_skin_id", "")),
		String(loadout_result.get("bubble_style_id", "")),
		String(loadout_result.get("bubble_skin_id", "")),
		team_id
	)
	room_service._broadcast_snapshot()


func handle_toggle_ready(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	if room_service.room_state.is_matchmade_room:
		room_service._log_room_service("toggle_ready_rejected_locked", room_service._build_online_service_context(null, message))
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_READY_LOCKED",
			"user_message": "Matchmade room readiness is automatic",
		})
		return
	room_service.room_state.toggle_ready(peer_id)
	room_service._broadcast_snapshot()
	room_service._maybe_auto_start_match()


func handle_start_request(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	if room_service.room_state.is_match_room():
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "MATCH_ROOM_START_FORBIDDEN",
			"user_message": "Match rooms must enter matchmaking queue",
		})
		return
	if room_service.room_state.is_matchmade_room:
		room_service._log_room_service("start_request_rejected_locked", room_service._build_online_service_context(null, message))
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_LOCKED",
			"user_message": "Matchmade room starts automatically",
		})
		return
	if room_service.room_state.match_active:
		room_service._log_room_service("start_blocked_match_active", room_service._build_start_gate_debug_context(message))
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "MATCH_ALREADY_ACTIVE",
			"user_message": "A match is already active",
		})
		return
	if room_service.room_state.get_distinct_team_ids().size() < 2:
		room_service._log_room_service("start_blocked_team_count", room_service._build_start_gate_debug_context(message))
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_TEAM_INVALID",
			"user_message": "At least two teams are required to start",
		})
		return
	if peer_id != room_service.room_state.owner_peer_id or not room_service.room_state.can_start():
		room_service._log_room_service("start_blocked_room_not_ready", room_service._build_start_gate_debug_context(message))
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready to start",
		})
		return
	# Enter loading barrier as active match immediately to keep room state
	# and directory visibility consistent during start->commit window.
	room_service.room_state.match_active = true
	if room_service.room_state.room_lifecycle_state == "idle":
		room_service.room_state.room_lifecycle_state = "gathering"
	room_service._broadcast_snapshot()
	room_service.start_match_requested.emit(room_service.room_state.build_snapshot())


func handle_leave_request(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var had_member = room_service.room_state.members.has(peer_id)
	if had_member:
		if room_service.room_state.is_match_room() and room_service.room_state.room_queue_state == "queueing":
			room_service._cancel_party_queue_backend()
			room_service._cancel_match_queue_locally("member_left")
		room_service.room_state.remove_member(peer_id)
		if room_service.room_state.members.is_empty():
			room_service.room_state.reset()
		room_service._broadcast_snapshot()
	room_service.send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_LEAVE_ACCEPTED,
		"room_id": room_service.room_state.room_id,
		"had_member": had_member,
	})


func handle_rematch_request(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	if room_service.room_state.is_matchmade_room:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "MATCHMADE_REMATCH_FORBIDDEN",
			"user_message": "Matchmade rooms return to lobby after settlement",
		})
		return
	if peer_id != room_service.room_state.owner_peer_id:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "REMATCH_FORBIDDEN",
			"user_message": "Only the host can request a rematch",
		})
		return
	if room_service.room_state.room_id.is_empty():
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Room does not exist",
		})
		return
	if room_service.room_state.match_active:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "MATCH_ALREADY_ACTIVE",
			"user_message": "A match is already active",
		})
		return
	if room_service.room_state.members.size() < room_service.room_state.min_start_players:
		room_service.send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "ROOM_NOT_READY",
			"user_message": "Room is not ready for rematch (member count too low)",
		})
		return
	for member_peer_id in room_service.room_state.members.keys():
		room_service.room_state.set_ready(member_peer_id, true)
	room_service.room_state.match_active = true
	room_service._broadcast_snapshot()
	room_service.start_match_requested.emit(room_service.room_state.build_snapshot())
