class_name ServerRoomBattleHandoffService
extends RefCounted


func handle_match_finished(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	restore_after_battle_return(room_service)
	room_service._broadcast_snapshot()
	if room_service.room_state.is_match_room():
		room_service._broadcast_match_queue_status()


func handle_loading_started(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.room_state.match_active = true
	room_service._broadcast_snapshot()


func handle_loading_aborted(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.room_state.match_active = false
	room_service._broadcast_snapshot()


func handle_match_committed(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.room_state.match_active = true
	room_service._broadcast_snapshot()


func handle_battle_return(room_service: Node, message: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var peer_id = int(message.get("sender_peer_id", 0))
	room_service._log_room_service("battle_return_received", {
		"peer_id": peer_id,
		"room_id": room_service.room_state.room_id if room_service.room_state != null else "",
		"queue_state": room_service.room_state.room_queue_state if room_service.room_state != null else "",
		"match_active": bool(room_service.room_state.match_active) if room_service.room_state != null else false,
		"battle_id": room_service.room_state.current_battle_id if room_service.room_state != null else "",
	})
	restore_after_battle_return(room_service)
	room_service._broadcast_snapshot()
	if room_service.room_state.is_match_room():
		room_service._broadcast_match_queue_status()


func poll_queue_status(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null or room_service.room_state.room_queue_state != "queueing":
		return
	if room_service.room_state.room_queue_entry_id.is_empty():
		return
	var now = Time.get_ticks_msec()
	if now - room_service._last_queue_poll_msec < room_service._queue_poll_interval_msec:
		return
	room_service._last_queue_poll_msec = now
	if room_service.game_service_party_queue_client == null or not room_service.game_service_party_queue_client.has_method("get_party_queue_status"):
		return
	var result = room_service.game_service_party_queue_client.get_party_queue_status(room_service.room_state.room_id, room_service.room_state.room_queue_entry_id)
	if not (result is Dictionary) or not bool(result.get("ok", false)):
		room_service._log_room_service("queue_poll_failed", result if result is Dictionary else {"error": "invalid_result"})
		return
	var queue_state = String(result.get("queue_state", ""))
	room_service._log_room_service("queue_poll_result", {"queue_state": queue_state, "assignment_id": String(result.get("assignment_id", ""))})
	if queue_state == "assigned" and not String(result.get("assignment_id", "")).is_empty():
		apply_queue_assignment(room_service, result)
	elif queue_state == "expired" or queue_state == "cancelled":
		cancel_match_queue_locally(room_service, queue_state)
		room_service._broadcast_snapshot()
		room_service._broadcast_match_queue_status()


func restore_after_battle_return(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.room_state.match_active = false
	room_service.room_state.reset_ready_state()
	room_service.room_state.room_queue_state = "idle"
	room_service.room_state.room_queue_entry_id = ""
	room_service.room_state.room_queue_status_text = ""
	room_service.room_state.room_queue_error_code = ""
	room_service.room_state.room_queue_error_message = ""
	room_service.room_state.room_lifecycle_state = "idle"
	room_service.room_state.current_assignment_id = ""
	room_service.room_state.current_battle_id = ""
	room_service.room_state.current_match_id = ""
	room_service.room_state.battle_allocation_state = ""
	room_service.room_state.battle_server_host = ""
	room_service.room_state.battle_server_port = 0


func apply_queue_assignment(room_service: Node, result: Dictionary) -> void:
	if room_service == null or room_service.room_state == null:
		return
	var assignment_id = String(result.get("assignment_id", ""))
	if assignment_id.is_empty():
		return
	room_service._log_room_service("queue_assignment_received", {
		"assignment_id": assignment_id,
		"room_id": String(result.get("room_id", "")),
		"server_host": String(result.get("server_host", "")),
		"server_port": int(result.get("server_port", 0)),
		"map_id": String(result.get("map_id", "")),
		"mode_id": String(result.get("mode_id", "")),
		"rule_set_id": String(result.get("rule_set_id", "")),
	})
	room_service.room_state.room_queue_state = "assigned"
	room_service.room_state.room_queue_status_text = String(result.get("queue_status_text", "Match found"))
	room_service.room_state.room_queue_error_code = ""
	room_service.room_state.room_queue_error_message = ""
	room_service._broadcast_snapshot()
	room_service._broadcast_match_queue_status()
	room_service.assignment_commit_requested.emit({
		"assignment_id": assignment_id,
		"room_id": String(result.get("room_id", "")),
		"room_kind": String(result.get("room_kind", "")),
		"server_host": String(result.get("server_host", "")),
		"server_port": int(result.get("server_port", 0)),
		"map_id": String(result.get("map_id", "")),
		"mode_id": String(result.get("mode_id", "")),
		"rule_set_id": String(result.get("rule_set_id", "")),
		"captain_account_id": String(result.get("captain_account_id", "")),
		"battle_id": String(result.get("battle_id", "")),
		"match_id": String(result.get("match_id", "")),
		"allocation_state": String(result.get("allocation_state", "")),
	})


func build_party_queue_request(room_service: Node) -> Dictionary:
	if room_service == null or room_service.room_state == null:
		return {}
	var members: Array[Dictionary] = []
	var seat_index = 0
	for binding in room_service.room_state._get_sorted_member_bindings():
		if binding == null:
			continue
		members.append({
			"account_id": String(binding.account_id),
			"profile_id": String(binding.profile_id),
			"device_session_id": String(binding.device_session_id),
			"seat_index": seat_index,
		})
		seat_index += 1
	if members.is_empty():
		for peer_id in room_service.room_state.get_sorted_peer_ids():
			var profile: Dictionary = room_service.room_state.members.get(peer_id, {})
			members.append({
				"account_id": String(profile.get("account_id", "")),
				"profile_id": String(profile.get("profile_id", "")),
				"device_session_id": String(profile.get("device_session_id", "")),
				"seat_index": seat_index,
			})
			seat_index += 1
	return {
		"party_room_id": room_service.room_state.room_id,
		"queue_type": room_service.room_state.queue_type,
		"match_format_id": room_service.room_state.match_format_id,
		"selected_mode_ids": room_service.room_state.selected_match_mode_ids.duplicate(),
		"members": members,
	}


func enter_party_queue_backend(room_service: Node, request: Dictionary) -> Dictionary:
	if room_service == null:
		return {
			"ok": false,
			"error_code": "PARTY_QUEUE_CLIENT_MISSING",
			"user_message": "Party queue service is not configured",
		}
	if room_service.game_service_party_queue_client == null or not room_service.game_service_party_queue_client.has_method("enter_party_queue"):
		return {
			"ok": false,
			"error_code": "PARTY_QUEUE_CLIENT_MISSING",
			"user_message": "Party queue service is not configured",
		}
	var result = room_service.game_service_party_queue_client.enter_party_queue(request)
	if result is Dictionary:
		return result
	return {
		"ok": false,
		"error_code": "PARTY_QUEUE_RESULT_INVALID",
		"user_message": "Party queue service returned invalid result",
	}


func cancel_party_queue_backend(room_service: Node) -> Dictionary:
	if room_service == null or room_service.room_state == null:
		return {"ok": true}
	if room_service.game_service_party_queue_client == null or not room_service.game_service_party_queue_client.has_method("cancel_party_queue"):
		return {"ok": true}
	var result = room_service.game_service_party_queue_client.cancel_party_queue(room_service.room_state.room_id, room_service.room_state.room_queue_entry_id)
	if result is Dictionary:
		return result
	return {
		"ok": false,
		"error_code": "PARTY_QUEUE_CANCEL_RESULT_INVALID",
		"user_message": "Party queue cancel returned invalid result",
	}


func cancel_match_queue_locally(room_service: Node, reason: String) -> void:
	if room_service == null or room_service.room_state == null:
		return
	room_service.room_state.room_queue_state = "cancelled"
	room_service.room_state.room_queue_entry_id = ""
	room_service.room_state.room_queue_status_text = "Queue cancelled"
	room_service.room_state.room_queue_error_code = ""
	room_service.room_state.room_queue_error_message = ""
	room_service._log_room_service("match_queue_cancelled_locally", {
		"room_id": room_service.room_state.room_id,
		"reason": reason,
	})


func maybe_auto_start_match(room_service: Node) -> void:
	if room_service == null or room_service.room_state == null or not room_service.room_state.is_matchmade_room:
		return
	if room_service.room_state.match_active:
		room_service._log_room_service("auto_start_skipped_match_active", room_service._build_online_service_context())
		return
	if room_service.room_state.expected_member_count <= 0:
		room_service._log_room_service("auto_start_skipped_missing_expected_count", room_service._build_online_service_context())
		return
	if room_service.room_state.members.size() != room_service.room_state.expected_member_count:
		room_service._log_room_service("auto_start_waiting_members", room_service._build_online_service_context())
		return
	if not room_service.room_state.can_start():
		room_service._log_room_service("auto_start_blocked_can_start_false", room_service._build_start_gate_debug_context())
		return
	room_service._log_room_service("auto_start_triggered", room_service._build_online_service_context())
	room_service.start_match_requested.emit(room_service.room_state.build_snapshot())
