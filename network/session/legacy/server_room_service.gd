class_name ServerRoomService
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const RoomTicketVerifierScript = preload("res://network/session/auth/room_ticket_verifier.gd")
const RoomResumeValidatorScript = preload("res://network/session/runtime/room_resume_validator.gd")
const MemberSessionPayloadBuilderScript = preload("res://network/session/runtime/member_session_payload_builder.gd")
const RoomSelectionPolicyScript = preload("res://network/session/runtime/room_selection_policy.gd")
const ServerRoomMemberServiceScript = preload("res://network/session/legacy/server_room_member_service.gd")
const ServerRoomMessageDispatcherScript = preload("res://network/session/legacy/server_room_message_dispatcher.gd")
const ServerRoomResumeServiceScript = preload("res://network/session/legacy/server_room_resume_service.gd")
const ServerRoomBattleHandoffServiceScript = preload("res://network/session/legacy/server_room_battle_handoff_service.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const MAX_PUBLIC_ROOM_DISPLAY_NAME_LENGTH: int = 24
const ROOM_SERVICE_LOG_TAG := "net.room_service"

signal room_snapshot_updated(snapshot: RoomSnapshot)
signal start_match_requested(snapshot: RoomSnapshot)
signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)
signal resume_request_received(message: Dictionary)  # LegacyMigration: For ServerRoomRuntime to handle match resume
signal assignment_commit_requested(payload: Dictionary)

var room_state: RoomServerState = RoomServerStateScript.new()
var room_ticket_verifier: RefCounted = RoomTicketVerifierScript.new()
var room_resume_validator: RefCounted = RoomResumeValidatorScript.new()
var member_session_payload_builder: RefCounted = MemberSessionPayloadBuilderScript.new()
var game_service_party_queue_client: RefCounted = null
var _queue_poll_interval_msec: int = 2000
var _last_queue_poll_msec: int = 0
var _member_service: RefCounted = null
var _message_dispatcher: RefCounted = null
var _resume_service: RefCounted = null
var _battle_handoff_service: RefCounted = null


func _ensure_sub_services() -> void:
	if _member_service == null:
		_member_service = ServerRoomMemberServiceScript.new()
	if _message_dispatcher == null:
		_message_dispatcher = ServerRoomMessageDispatcherScript.new()
	if _resume_service == null:
		_resume_service = ServerRoomResumeServiceScript.new()
	if _battle_handoff_service == null:
		_battle_handoff_service = ServerRoomBattleHandoffServiceScript.new()


func configure_room_ticket_verifier(secret: String, allow_unsigned_dev_ticket: bool = false) -> void:
	if room_ticket_verifier == null:
		room_ticket_verifier = RoomTicketVerifierScript.new()
	if room_ticket_verifier.has_method("configure"):
		room_ticket_verifier.configure(secret, allow_unsigned_dev_ticket)


func configure_party_queue_client(client: RefCounted) -> void:
	game_service_party_queue_client = client


func handle_peer_disconnected(peer_id: int) -> void:
	_ensure_sub_services()
	_member_service.handle_peer_disconnected(self, peer_id)


func handle_match_finished() -> void:
	_ensure_sub_services()
	_battle_handoff_service.handle_match_finished(self)


func handle_loading_started() -> void:
	_ensure_sub_services()
	_battle_handoff_service.handle_loading_started(self)


func handle_loading_aborted() -> void:
	_ensure_sub_services()
	_battle_handoff_service.handle_loading_aborted(self)


func handle_match_committed() -> void:
	_ensure_sub_services()
	_battle_handoff_service.handle_match_committed(self)


func poll_idle_resume_expired() -> void:
	_ensure_sub_services()
	_resume_service.poll_idle_resume_expired(self)


func handle_message(message: Dictionary) -> void:
	_ensure_sub_services()
	_message_dispatcher.dispatch_message(self, message)


func _handle_create_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var ticket_validation = room_ticket_verifier.verify_create_ticket(message) if room_ticket_verifier != null else null
	if ticket_validation == null or not bool(ticket_validation.ok):
		_reject_with_ticket_error(peer_id, TransportMessageTypesScript.ROOM_CREATE_REJECTED, ticket_validation)
		return
	var ticket_claim = ticket_validation.claim
	if not _is_matchmade_ticket_compatible(ticket_claim):
		_log_room_service("create_request_matchmade_ticket_incompatible", _build_online_service_context(ticket_claim, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "MATCHMAKING_ASSIGNMENT_REVISION_STALE",
			"user_message": "Match assignment ticket is stale",
		})
		return
	var loadout_result := RoomSelectionPolicyScript.resolve_request_loadout(message, room_ticket_verifier, ticket_claim)
	if not bool(loadout_result.get("ok", false)):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": String(loadout_result.get("error", "ROOM_MEMBER_PROFILE_INVALID")),
			"user_message": String(loadout_result.get("user_message", "Character selection is invalid")),
		})
		return
	var requested_room_id := String(message.get("room_id_hint", "")).strip_edges()
	var requested_room_kind := String(message.get("room_kind", "private_room")).strip_edges().to_lower()
	var requested_room_display_name := String(message.get("room_display_name", "")).strip_edges()
	if requested_room_kind != "private_room" \
		and requested_room_kind != "public_room" \
		and requested_room_kind != "matchmade_room" \
		and requested_room_kind != "casual_match_room" \
		and requested_room_kind != "ranked_match_room":
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "ROOM_KIND_INVALID",
			"user_message": "Room kind is invalid",
		})
		return
	if String(ticket_claim.room_kind).strip_edges().to_lower() == "matchmade_room":
		requested_room_kind = "matchmade_room"
	if requested_room_kind == "public_room":
		requested_room_display_name = requested_room_display_name.substr(0, MAX_PUBLIC_ROOM_DISPLAY_NAME_LENGTH)
		if requested_room_display_name.is_empty():
			send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
				"error": "ROOM_DISPLAY_NAME_REQUIRED",
				"user_message": "Public room name is required",
			})
			return
	
	# LegacyMigration: Reject create if room already exists (single-room-per-DS model)
	if not room_state.room_id.is_empty():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "ROOM_ALREADY_EXISTS",
			"user_message": "房间已存在",
		})
		return
	elif requested_room_kind == "matchmade_room":
		requested_room_display_name = "Matchmade Room"
	elif requested_room_kind == "casual_match_room":
		requested_room_display_name = "Casual Match Room"
	elif requested_room_kind == "ranked_match_room":
		requested_room_display_name = "Ranked Match Room"
	else:
		requested_room_display_name = requested_room_display_name.substr(0, MAX_PUBLIC_ROOM_DISPLAY_NAME_LENGTH)
	room_state.ensure_room(requested_room_id, peer_id, requested_room_kind, requested_room_display_name)
	_apply_ticket_claim_to_room_state(ticket_claim)
	# Initialize default match modes for match rooms so enter_queue works without explicit config
	if room_state.is_match_room():
		var default_modes := _get_eligible_match_mode_ids(room_state.queue_type, room_state.match_format_id)
		if not default_modes.is_empty():
			room_state.selected_match_mode_ids = default_modes
	var resolved_selection := _resolve_selection_from_map(
		room_ticket_verifier.resolve_requested_map_id(message, ticket_claim),
		room_ticket_verifier.resolve_requested_rule_set_id(message, ticket_claim),
		room_ticket_verifier.resolve_requested_mode_id(message, ticket_claim),
		not room_state.is_matchmade_room
	)
	if resolved_selection.is_empty():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "ROOM_SELECTION_INVALID",
			"user_message": "Map selection is invalid",
		})
		return
	_log_room_service("create_request_selection_resolved", _with_service_debug_payload(_build_online_service_context(ticket_claim, message), {
		"visibility": requested_room_kind,
		"default_map_id": String(resolved_selection.get("map_id", "")),
		"derived_mode_id": String(resolved_selection.get("mode_id", "")),
		"derived_rule_set_id": String(resolved_selection.get("rule_set_id", "")),
	}))
	room_state.set_selection(
		String(resolved_selection.get("map_id", "")),
		String(resolved_selection.get("rule_set_id", "")),
		String(resolved_selection.get("mode_id", ""))
	)
	room_state.upsert_member(
		peer_id,
		ticket_claim.display_name if not ticket_claim.display_name.is_empty() else String(message.get("player_name", "Player%d" % peer_id)),
		String(loadout_result.get("character_id", "")),
		String(loadout_result.get("character_skin_id", "")),
		String(loadout_result.get("bubble_style_id", "")),
		String(loadout_result.get("bubble_skin_id", "")),
		room_ticket_verifier.resolve_requested_team_id(message, ticket_claim),
		ticket_claim.account_id,
		ticket_claim.profile_id,
		ticket_claim.device_session_id,
		ticket_claim.ticket_id,
		"profile"
	)
	room_state.set_ready(peer_id, bool(ticket_claim.auto_ready_on_join))
	send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_ACCEPTED,
		"room_id": room_state.room_id,
		"owner_peer_id": room_state.owner_peer_id,
		"room_kind": room_state.room_kind,
		"room_display_name": room_state.room_display_name,
	})
	_emit_assignment_commit_if_needed(ticket_claim)
	_log_room_service("create_request_accepted", _build_online_service_context(ticket_claim, message))
	
	var binding := room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		_send_member_session(peer_id, binding)
	
	_broadcast_snapshot()
	_maybe_auto_start_match()


func _handle_join_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var ticket_validation = room_ticket_verifier.verify_join_ticket(message) if room_ticket_verifier != null else null
	if ticket_validation == null or not bool(ticket_validation.ok):
		_reject_with_ticket_error(peer_id, TransportMessageTypesScript.ROOM_JOIN_REJECTED, ticket_validation)
		return
	var ticket_claim = ticket_validation.claim
	if not _is_matchmade_ticket_compatible(ticket_claim):
		_log_room_service("join_request_matchmade_ticket_incompatible", _build_online_service_context(ticket_claim, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "MATCHMAKING_ASSIGNMENT_REVISION_STALE",
			"user_message": "Match assignment ticket is stale",
		})
		return
	if room_state.is_matchmade_room and String(ticket_claim.room_kind).strip_edges().to_lower() != "matchmade_room":
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "MATCHMADE_ROOM_MANUAL_JOIN_FORBIDDEN",
			"user_message": "Matchmade room requires assignment ticket",
		})
		return
	var loadout_result := RoomSelectionPolicyScript.resolve_request_loadout(message, room_ticket_verifier, ticket_claim)
	if not bool(loadout_result.get("ok", false)):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": String(loadout_result.get("error", "ROOM_MEMBER_PROFILE_INVALID")),
			"user_message": String(loadout_result.get("user_message", "Character selection is invalid")),
		})
		return
	var requested_room_id := String(message.get("room_id_hint", "")).strip_edges()
	if room_state.room_id.is_empty() or requested_room_id.is_empty() or room_state.room_id != requested_room_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Target room does not exist",
		})
		return
	
	# LegacyMigration: Reject normal join during active match
	if room_state.match_active:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "MATCH_ACTIVE_PLAYER_JOIN_FORBIDDEN",
			"user_message": "Active match is not joinable as a player",
		})
		return
	
	# LegacyMigration: Reject join when room is at capacity
	if room_state.is_match_room():
		if room_state.members.size() >= room_state.required_party_size:
			send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
				"error": "ROOM_MATCH_CAPACITY_FULL",
				"user_message": "匹配房间已满员",
			})
			return
	elif room_state.max_players > 0:
		if room_state.members.size() >= room_state.max_players:
			send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
				"error": "ROOM_CAPACITY_FULL",
				"user_message": "房间已满员",
			})
			return
	
	_apply_ticket_claim_to_room_state(ticket_claim)
	room_state.upsert_member(
		peer_id,
		ticket_claim.display_name if not ticket_claim.display_name.is_empty() else String(message.get("player_name", "Player%d" % peer_id)),
		String(loadout_result.get("character_id", "")),
		String(loadout_result.get("character_skin_id", "")),
		String(loadout_result.get("bubble_style_id", "")),
		String(loadout_result.get("bubble_skin_id", "")),
		room_ticket_verifier.resolve_requested_team_id(message, ticket_claim),
		ticket_claim.account_id,
		ticket_claim.profile_id,
		ticket_claim.device_session_id,
		ticket_claim.ticket_id,
		"profile"
	)
	room_state.set_ready(peer_id, bool(ticket_claim.auto_ready_on_join))
	send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_ACCEPTED,
		"room_id": room_state.room_id,
		"owner_peer_id": room_state.owner_peer_id,
	})
	
	var binding := room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		_send_member_session(peer_id, binding)
	
	_broadcast_snapshot()
	_maybe_auto_start_match()
	_log_room_service("join_request_accepted", _build_online_service_context(ticket_claim, message))


func _handle_update_profile(message: Dictionary) -> void:
	_ensure_sub_services()
	_member_service.handle_update_profile(self, message)


func _handle_update_selection(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_state.is_match_room():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "MATCH_ROOM_SELECTION_FORBIDDEN",
			"user_message": "Match rooms use match format and mode pool",
		})
		return
	if room_state.is_matchmade_room:
		_log_room_service("update_selection_rejected_locked", _build_online_service_context(null, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_SELECTION_LOCKED",
			"user_message": "Matchmade room selection is locked",
		})
		return
	if peer_id != room_state.owner_peer_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_FORBIDDEN",
			"user_message": "Only the host can change room selection",
		})
		return
	var map_id := String(message.get("map_id", ""))
	var old_map_id := String(room_state.selected_map_id)
	var resolved_selection := _resolve_selection_from_map(
		map_id,
		String(message.get("rule_set_id", "")),
		String(message.get("mode_id", "")),
		false
	)
	if resolved_selection.is_empty():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_SELECTION_INVALID",
			"user_message": "Map selection is invalid",
		})
		return
	room_state.set_selection(
		String(resolved_selection.get("map_id", "")),
		String(resolved_selection.get("rule_set_id", "")),
		String(resolved_selection.get("mode_id", ""))
	)
	_log_room_service("room_selection_changed", _with_service_debug_payload(_build_online_service_context(null, message), {
		"old_map_id": old_map_id,
		"new_map_id": String(resolved_selection.get("map_id", "")),
		"derived_mode_id": String(resolved_selection.get("mode_id", "")),
		"derived_rule_set_id": String(resolved_selection.get("rule_set_id", "")),
	}))
	_broadcast_snapshot()


func _handle_update_match_room_config(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if not room_state.can_update_match_room_config(peer_id):
		_send_match_queue_status(peer_id, "MATCH_ROOM_CONFIG_FORBIDDEN", "Match room config cannot be changed")
		return
	var next_format_id := String(message.get("match_format_id", "1v1")).strip_edges()
	if not _is_valid_match_format_id(next_format_id):
		_send_match_queue_status(peer_id, "MATCH_FORMAT_INVALID", "Match format is invalid")
		_broadcast_snapshot()
		return
	var selected_mode_ids := _to_string_array(message.get("selected_mode_ids", []))
	var eligible_mode_ids := _get_eligible_match_mode_ids(room_state.queue_type, next_format_id)
	for mode_id in selected_mode_ids:
		if not eligible_mode_ids.has(mode_id):
			_send_match_queue_status(peer_id, "MATCH_MODE_INVALID", "Selected mode is not available for this queue")
			_broadcast_snapshot()
			return
	room_state.match_format_id = next_format_id
	room_state.required_party_size = room_state.resolve_required_party_size(next_format_id)
	room_state.selected_match_mode_ids = selected_mode_ids
	room_state.room_queue_state = "idle"
	room_state.room_queue_status_text = ""
	room_state.max_players = room_state.required_party_size
	room_state.min_start_players = room_state.required_party_size
	room_state.room_queue_error_code = ""
	room_state.room_queue_error_message = ""
	_broadcast_snapshot()


func _handle_enter_match_queue(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	_log_room_service("enter_match_queue_received", {
		"peer_id": peer_id,
		"room_id": room_state.room_id if room_state != null else "",
		"can_enter": room_state.can_enter_match_queue(peer_id) if room_state != null else false,
	})
	if not room_state.can_enter_match_queue(peer_id):
		var diag := room_state.diagnose_enter_match_queue(peer_id) if room_state != null and room_state.has_method("diagnose_enter_match_queue") else {}
		_log_room_service("enter_match_queue_forbidden", diag)
		_send_match_queue_status(peer_id, "MATCH_ROOM_QUEUE_FORBIDDEN", "Match room is not ready to enter queue")
		_broadcast_snapshot()
		return
	var request := _build_party_queue_request()
	_log_room_service("enter_match_queue_backend_request", request)
	var result := _enter_party_queue_backend(request)
	_log_room_service("enter_match_queue_backend_result", result)
	if not bool(result.get("ok", false)):
		_send_match_queue_status(
			peer_id,
			String(result.get("error_code", "PARTY_QUEUE_ENTER_FAILED")),
			String(result.get("user_message", "Failed to enter matchmaking queue"))
		)
		_broadcast_snapshot()
		return
	room_state.room_queue_state = "queueing"
	room_state.room_queue_entry_id = String(result.get("queue_entry_id", result.get("party_queue_entry_id", "")))
	room_state.room_queue_status_text = String(result.get("queue_status_text", "Queueing"))
	room_state.room_queue_error_code = ""
	room_state.room_queue_error_message = ""
	_last_queue_poll_msec = Time.get_ticks_msec()
	_broadcast_snapshot()
	_broadcast_match_queue_status()
	# If game_service already assigned on enter, handle immediately
	if String(result.get("queue_state", "")) == "assigned" and not String(result.get("assignment_id", "")).is_empty():
		_apply_queue_assignment(result)


func _handle_cancel_match_queue(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if not room_state.is_match_room():
		_send_match_queue_status(peer_id, "NOT_MATCH_ROOM", "Current room is not a match room")
		return
	if peer_id != room_state.owner_peer_id:
		_send_match_queue_status(peer_id, "MATCH_QUEUE_CANCEL_FORBIDDEN", "Only the host can cancel matchmaking")
		return
	var result := _cancel_party_queue_backend()
	if not bool(result.get("ok", false)):
		_send_match_queue_status(
			peer_id,
			String(result.get("error_code", "PARTY_QUEUE_CANCEL_FAILED")),
			String(result.get("user_message", "Failed to cancel matchmaking queue"))
		)
		_broadcast_snapshot()
		return
	_cancel_match_queue_locally("host_cancelled")
	_broadcast_snapshot()
	_broadcast_match_queue_status()


func _handle_battle_return(message: Dictionary) -> void:
	_ensure_sub_services()
	_battle_handoff_service.handle_battle_return(self, message)


func poll_queue_status() -> void:
	_ensure_sub_services()
	_battle_handoff_service.poll_queue_status(self)


func _restore_after_battle_return() -> void:
	_ensure_sub_services()
	_battle_handoff_service.restore_after_battle_return(self)


func _apply_queue_assignment(result: Dictionary) -> void:
	_ensure_sub_services()
	_battle_handoff_service.apply_queue_assignment(self, result)


func _handle_toggle_ready(message: Dictionary) -> void:
	_ensure_sub_services()
	_member_service.handle_toggle_ready(self, message)


func _handle_start_request(message: Dictionary) -> void:
	_ensure_sub_services()
	_member_service.handle_start_request(self, message)


func _handle_leave_request(message: Dictionary) -> void:
	_ensure_sub_services()
	_member_service.handle_leave_request(self, message)


func _handle_rematch_request(message: Dictionary) -> void:
	_ensure_sub_services()
	_member_service.handle_rematch_request(self, message)


func _broadcast_snapshot() -> void:
	_ensure_sub_services()
	_message_dispatcher.broadcast_snapshot(self)


func _broadcast_match_queue_status() -> void:
	_ensure_sub_services()
	_message_dispatcher.broadcast_match_queue_status(self)


func _send_match_queue_status(peer_id: int, error_code: String = "", user_message: String = "") -> void:
	_ensure_sub_services()
	_message_dispatcher.send_match_queue_status(self, peer_id, error_code, user_message)


func _build_party_queue_request() -> Dictionary:
	_ensure_sub_services()
	return _battle_handoff_service.build_party_queue_request(self)


func _enter_party_queue_backend(request: Dictionary) -> Dictionary:
	_ensure_sub_services()
	return _battle_handoff_service.enter_party_queue_backend(self, request)


func _cancel_party_queue_backend() -> Dictionary:
	_ensure_sub_services()
	return _battle_handoff_service.cancel_party_queue_backend(self)


func _cancel_match_queue_locally(reason: String) -> void:
	_ensure_sub_services()
	_battle_handoff_service.cancel_match_queue_locally(self, reason)


func _apply_ticket_claim_to_room_state(ticket_claim) -> void:
	if room_state == null or ticket_claim == null:
		return
	if String(ticket_claim.room_kind).strip_edges().to_lower() != "matchmade_room":
		return
	room_state.assignment_id = String(ticket_claim.assignment_id)
	room_state.assignment_revision = int(ticket_claim.assignment_revision)
	room_state.season_id = String(ticket_claim.season_id)
	room_state.expected_member_count = int(ticket_claim.expected_member_count)
	room_state.locked_map_id = String(ticket_claim.locked_map_id)
	room_state.locked_rule_set_id = String(ticket_claim.locked_rule_set_id)
	room_state.locked_mode_id = String(ticket_claim.locked_mode_id)
	room_state.is_matchmade_room = String(ticket_claim.room_kind).strip_edges().to_lower() == "matchmade_room"
	if room_state.is_matchmade_room:
		room_state.room_kind = "matchmade_room"
		room_state.is_public_room = false
		room_state.room_display_name = "Matchmade Room"


func _is_matchmade_ticket_compatible(ticket_claim) -> bool:
	if ticket_claim == null:
		return false
	if String(ticket_claim.room_kind).strip_edges().to_lower() != "matchmade_room":
		return true
	if String(ticket_claim.assignment_id).strip_edges().is_empty():
		return false
	if int(ticket_claim.assignment_revision) <= 0:
		return false
	if int(ticket_claim.expected_member_count) <= 0:
		return false
	if String(ticket_claim.locked_map_id).strip_edges().is_empty():
		return false
	if String(ticket_claim.locked_rule_set_id).strip_edges().is_empty():
		return false
	if String(ticket_claim.locked_mode_id).strip_edges().is_empty():
		return false
	if room_state == null or room_state.room_id.is_empty():
		return true
	if String(room_state.assignment_id) != String(ticket_claim.assignment_id):
		return false
	if int(room_state.assignment_revision) > 0 and int(ticket_claim.assignment_revision) != int(room_state.assignment_revision):
		return false
	return true


func _emit_assignment_commit_if_needed(ticket_claim) -> void:
	if ticket_claim == null:
		return
	if String(ticket_claim.room_kind).strip_edges().to_lower() != "matchmade_room":
		return
	if String(ticket_claim.purpose) != "create":
		return
	assignment_commit_requested.emit({
		"assignment_id": String(ticket_claim.assignment_id),
		"account_id": String(ticket_claim.account_id),
		"profile_id": String(ticket_claim.profile_id),
		"assignment_revision": int(ticket_claim.assignment_revision),
		"room_id": String(ticket_claim.room_id),
	})
	_log_room_service("assignment_commit_emitted", {
		"assignment_id": String(ticket_claim.assignment_id),
		"assignment_revision": int(ticket_claim.assignment_revision),
		"account_id": String(ticket_claim.account_id),
		"profile_id": String(ticket_claim.profile_id),
		"room_id": String(ticket_claim.room_id),
	})


func _maybe_auto_start_match() -> void:
	_ensure_sub_services()
	_battle_handoff_service.maybe_auto_start_match(self)


# LegacyMigration: Resume request handling

func _handle_resume_request(message: Dictionary) -> void:
	_ensure_sub_services()
	_resume_service.handle_resume_request(self, message)


func _send_member_session(peer_id: int, binding: RoomMemberBindingState) -> void:
	_ensure_sub_services()
	_resume_service.send_member_session(self, peer_id, binding)


func _reject_with_ticket_error(peer_id: int, message_type: String, validation_result) -> void:
	_ensure_sub_services()
	_message_dispatcher.reject_with_ticket_error(self, peer_id, message_type, validation_result)


func _build_online_service_context(ticket_claim = null, message: Dictionary = {}) -> Dictionary:
	return {
		"room_id": String(room_state.room_id) if room_state != null else "",
		"room_kind": String(room_state.room_kind) if room_state != null else "",
		"assignment_id": String(ticket_claim.assignment_id) if ticket_claim != null else (String(room_state.assignment_id) if room_state != null else ""),
		"assignment_revision": int(ticket_claim.assignment_revision) if ticket_claim != null else (int(room_state.assignment_revision) if room_state != null else 0),
		"season_id": String(ticket_claim.season_id) if ticket_claim != null else (String(room_state.season_id) if room_state != null else ""),
		"sender_peer_id": int(message.get("sender_peer_id", 0)),
		"message_type": String(message.get("message_type", "")),
		"member_count": room_state.members.size() if room_state != null else 0,
		"expected_member_count": int(room_state.expected_member_count) if room_state != null else 0,
		"match_active": bool(room_state.match_active) if room_state != null else false,
	}


func _log_room_service(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("[server_room_service] %s %s" % [event_name, JSON.stringify(payload)], "", 0, ROOM_SERVICE_LOG_TAG)


func _with_service_debug_payload(base_payload: Dictionary, extra_payload: Dictionary) -> Dictionary:
	var payload := base_payload.duplicate(true)
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	return payload


func _build_start_gate_debug_context(message: Dictionary = {}) -> Dictionary:
	var payload := _build_online_service_context(null, message)
	var binding := MapSelectionCatalogScript.get_map_binding(String(room_state.selected_map_id)) if room_state != null else {}
	var required_team_count := int(binding.get("required_team_count", room_state.min_start_players if room_state != null else 0))
	var max_player_count := int(binding.get("max_player_count", room_state.max_players if room_state != null else 0))
	var non_empty_team_count := room_state.get_distinct_team_ids().size() if room_state != null else 0
	payload["map_id"] = String(room_state.selected_map_id) if room_state != null else ""
	payload["rule_set_id"] = String(room_state.selected_rule_id) if room_state != null else ""
	payload["mode_id"] = String(room_state.selected_mode_id) if room_state != null else ""
	payload["required_team_count"] = required_team_count
	payload["non_empty_team_count"] = non_empty_team_count
	payload["member_count"] = room_state.members.size() if room_state != null else 0
	payload["max_player_count"] = max_player_count
	payload["all_ready"] = _are_all_members_ready()
	return payload


func _are_all_members_ready() -> bool:
	if room_state == null:
		return false
	for peer_id in room_state.members.keys():
		if not bool(room_state.ready_map.get(peer_id, false)):
			return false
	return true


func _resolve_selection_from_map(map_id: String, fallback_rule_set_id: String, fallback_mode_id: String, allow_custom_default: bool) -> Dictionary:
	var resolved_map_id := map_id
	if resolved_map_id.is_empty() and allow_custom_default:
		resolved_map_id = MapSelectionCatalogScript.get_default_custom_room_map_id()
	if resolved_map_id.is_empty():
		return {}
	if not MapCatalogScript.has_map(resolved_map_id):
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(resolved_map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return {}
	return {
		"map_id": resolved_map_id,
		"rule_set_id": String(binding.get("bound_rule_set_id", fallback_rule_set_id)),
		"mode_id": String(binding.get("bound_mode_id", fallback_mode_id)),
	}


func _is_valid_match_format_id(match_format_id: String) -> bool:
	return ["1v1", "2v2", "4v4"].has(match_format_id)


func _get_eligible_match_mode_ids(queue_type: String, match_format_id: String) -> Array[String]:
	var result: Array[String] = []
	for entry in MapSelectionCatalogScript.get_match_room_mode_entries(queue_type, match_format_id):
		var mode_id := String(entry.get("mode_id", entry.get("id", "")))
		if not mode_id.is_empty() and bool(entry.get("enabled", true)) and not result.has(mode_id):
			result.append(mode_id)
	return result


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result
