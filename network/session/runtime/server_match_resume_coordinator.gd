class_name ServerMatchResumeCoordinator
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomMemberBindingStateScript = preload("res://network/session/runtime/room_member_binding_state.gd")
const MatchResumeSnapshotScript = preload("res://network/session/runtime/match_resume_snapshot.gd")

signal send_to_peer(peer_id: int, message: Dictionary)
signal match_abort_requested(reason: String, member_id: String)

var resume_window_sec: float = 20.0

var _room_state: RoomServerState = null
var _match_service: ServerMatchService = null


func configure(room_state: RoomServerState, match_service: ServerMatchService) -> void:
	_room_state = room_state
	_match_service = match_service


func on_match_committed(config: BattleStartConfig) -> void:
	if _room_state == null or config == null:
		return
	# Freeze match peer bindings and record match_id
	_room_state.freeze_match_peer_bindings(config.match_id)
	# Clear any stale resume windows
	_room_state.clear_resume_state()


func on_member_disconnected(member_id: String) -> void:
	if _room_state == null or _match_service == null:
		return
	if not _match_service.is_match_active():
		return
	
	var binding := _room_state.get_member_binding_by_member_id(member_id)
	if binding == null:
		return
	
	var deadline_msec := Time.get_ticks_msec() + int(resume_window_sec * 1000.0)
	var current_match_id := ""
	if _match_service.get_current_config() != null:
		current_match_id = _match_service.get_current_config().match_id
	
	_room_state.mark_member_disconnected_by_transport_peer(binding.transport_peer_id, deadline_msec, current_match_id)


func try_resume(member_id: String, reconnect_token: String, transport_peer_id: int, requested_match_id: String) -> Dictionary:
	if _room_state == null or _match_service == null:
		return {"ok": false, "error": "STATE_MISSING"}
	
	var binding := _room_state.get_member_binding_by_member_id(member_id)
	if binding == null:
		return {"ok": false, "error": "MEMBER_NOT_FOUND"}
	
	if not binding.is_reconnect_token_valid(reconnect_token):
		return {"ok": false, "error": "TOKEN_INVALID"}
	
	if not _match_service.is_match_active():
		return {"ok": false, "error": "MATCH_NOT_ACTIVE"}
	
	# Validate match_id if provided
	if not requested_match_id.is_empty():
		var current_config := _match_service.get_current_config()
		if current_config == null or current_config.match_id != requested_match_id:
			return {"ok": false, "error": "MATCH_ID_MISMATCH"}
	
	# Check deadline
	if binding.disconnect_deadline_msec > 0:
		var current_time := Time.get_ticks_msec()
		if current_time > binding.disconnect_deadline_msec:
			return {"ok": false, "error": "RESUME_WINDOW_EXPIRED"}
	
	# Build resume snapshot
	var current_config := _match_service.get_current_config()
	var checkpoint_message := _match_service.build_resume_checkpoint_message()
	
	if checkpoint_message.is_empty():
		return {"ok": false, "error": "CHECKPOINT_BUILD_FAILED"}

	# Rebind transport only after the battle payload is known to be valid.
	_room_state.bind_transport_to_member(member_id, transport_peer_id)
	binding.connection_state = "connected"
	binding.disconnect_deadline_msec = 0
	
	var resume_snapshot := MatchResumeSnapshotScript.new()
	resume_snapshot.room_id = _room_state.room_id
	resume_snapshot.room_kind = _room_state.room_kind
	resume_snapshot.room_display_name = _room_state.room_display_name
	resume_snapshot.match_id = current_config.match_id if current_config != null else ""
	resume_snapshot.server_match_revision = current_config.server_match_revision if current_config != null else 0
	resume_snapshot.member_id = member_id
	resume_snapshot.controlled_peer_id = binding.match_peer_id
	resume_snapshot.transport_peer_id = transport_peer_id
	resume_snapshot.resume_phase = "resuming"
	resume_snapshot.resume_tick = int(checkpoint_message.get("tick", 0))
	resume_snapshot.checkpoint_message = checkpoint_message
	resume_snapshot.status_message = "Resuming active match"
	
	var resume_config := _build_resume_candidate_config(current_config, transport_peer_id, binding.match_peer_id)

	# Send MATCH_RESUME_ACCEPTED
	send_to_peer.emit(transport_peer_id, {
		"message_type": TransportMessageTypesScript.MATCH_RESUME_ACCEPTED,
		"start_config": resume_config.to_dict() if resume_config != null else {},
		"resume_snapshot": resume_snapshot.to_dict(),
	})
	
	return {"ok": true, "resume_snapshot": resume_snapshot}


func poll_expired() -> void:
	if _room_state == null or _match_service == null:
		return
	if not _match_service.is_match_active():
		return
	
	var current_time := Time.get_ticks_msec()
	
	for member_id in _room_state.member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = _room_state.member_bindings_by_member_id[member_id]
		if binding.connection_state == "disconnected" and binding.disconnect_deadline_msec > 0:
			if current_time > binding.disconnect_deadline_msec:
				match_abort_requested.emit("peer_resume_timeout", member_id)


func clear_match_state() -> void:
	if _room_state == null:
		return
	_room_state.clear_resume_state()


func _build_resume_candidate_config(config: BattleStartConfig, transport_peer_id: int, controlled_peer_id: int) -> BattleStartConfig:
	if config == null:
		return null
	var resume_config := config.duplicate_deep()
	resume_config.build_mode = BattleStartConfig.BUILD_MODE_CANDIDATE
	resume_config.session_mode = "network_client"
	resume_config.topology = "dedicated_server"
	resume_config.local_peer_id = transport_peer_id
	resume_config.controlled_peer_id = controlled_peer_id
	return resume_config
