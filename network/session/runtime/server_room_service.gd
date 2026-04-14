class_name ServerRoomService
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const RoomTicketVerifierScript = preload("res://network/session/auth/room_ticket_verifier.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const MAX_PUBLIC_ROOM_DISPLAY_NAME_LENGTH: int = 24
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

signal room_snapshot_updated(snapshot: RoomSnapshot)
signal start_match_requested(snapshot: RoomSnapshot)
signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)
signal resume_request_received(message: Dictionary)  # Phase17: For ServerRoomRuntime to handle match resume
signal assignment_commit_requested(payload: Dictionary)

var room_state: RoomServerState = RoomServerStateScript.new()
var room_ticket_verifier: RefCounted = RoomTicketVerifierScript.new()


func configure_room_ticket_verifier(secret: String, allow_unsigned_dev_ticket: bool = false) -> void:
	if room_ticket_verifier == null:
		room_ticket_verifier = RoomTicketVerifierScript.new()
	if room_ticket_verifier.has_method("configure"):
		room_ticket_verifier.configure(secret, allow_unsigned_dev_ticket)


func handle_peer_disconnected(peer_id: int) -> void:
	if room_state == null:
		return
	var binding := room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null and not room_state.match_active:
		room_state.mark_member_disconnected_by_transport_peer(
			peer_id,
			Time.get_ticks_msec() + 20000,
			""
		)
		_broadcast_snapshot()
		return
	if not room_state.members.has(peer_id):
		return
	room_state.remove_member(peer_id)
	if room_state.members.is_empty():
		room_state.reset()
	_broadcast_snapshot()


func handle_match_finished() -> void:
	if room_state == null:
		return
	room_state.match_active = false
	room_state.reset_ready_state()
	_broadcast_snapshot()


func handle_loading_started() -> void:
	if room_state == null:
		return
	room_state.match_active = true
	_broadcast_snapshot()


func handle_loading_aborted() -> void:
	if room_state == null:
		return
	room_state.match_active = false
	_broadcast_snapshot()


func handle_match_committed() -> void:
	if room_state == null:
		return
	room_state.match_active = true
	_broadcast_snapshot()


func poll_idle_resume_expired() -> void:
	if room_state == null or room_state.match_active:
		return
	var current_time := Time.get_ticks_msec()
	var expired_peer_ids: Array[int] = []
	for member_id in room_state.member_bindings_by_member_id.keys():
		var binding = room_state.member_bindings_by_member_id[member_id]
		if binding == null:
			continue
		if String(binding.connection_state) != "disconnected":
			continue
		if int(binding.disconnect_deadline_msec) <= 0 or current_time <= int(binding.disconnect_deadline_msec):
			continue
		var peer_id := int(binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id)
		if peer_id > 0:
			expired_peer_ids.append(peer_id)
	if expired_peer_ids.is_empty():
		return
	for peer_id in expired_peer_ids:
		room_state.remove_member(peer_id)
	if room_state.members.is_empty():
		room_state.reset()
	_broadcast_snapshot()


func handle_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.ROOM_CREATE_REQUEST:
			_handle_create_request(message)
		TransportMessageTypesScript.ROOM_JOIN_REQUEST:
			_handle_join_request(message)
		TransportMessageTypesScript.ROOM_UPDATE_PROFILE:
			_handle_update_profile(message)
		TransportMessageTypesScript.ROOM_UPDATE_SELECTION:
			_handle_update_selection(message)
		TransportMessageTypesScript.ROOM_TOGGLE_READY:
			_handle_toggle_ready(message)
		TransportMessageTypesScript.ROOM_START_REQUEST:
			_handle_start_request(message)
		TransportMessageTypesScript.ROOM_LEAVE:
			_handle_leave_request(message)
		TransportMessageTypesScript.ROOM_REMATCH_REQUEST:
			_handle_rematch_request(message)
		TransportMessageTypesScript.ROOM_RESUME_REQUEST:
			_handle_resume_request(message)
		_:
			pass


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
		_log_online_room_service("create_request_matchmade_ticket_incompatible", _build_online_service_context(ticket_claim, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "MATCHMAKING_ASSIGNMENT_REVISION_STALE",
			"user_message": "Match assignment ticket is stale",
		})
		return
	var requested_character_id := String(message.get("character_id", "")).strip_edges()
	if requested_character_id.is_empty() or not CharacterCatalogScript.has_character(requested_character_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
		})
		return
	var requested_room_id := String(message.get("room_id_hint", "")).strip_edges()
	var requested_room_kind := String(message.get("room_kind", "private_room")).strip_edges().to_lower()
	var requested_room_display_name := String(message.get("room_display_name", "")).strip_edges()
	if requested_room_kind != "private_room" and requested_room_kind != "public_room" and requested_room_kind != "matchmade_room":
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
	elif requested_room_kind == "matchmade_room":
		requested_room_display_name = "Matchmade Room"
	else:
		requested_room_display_name = requested_room_display_name.substr(0, MAX_PUBLIC_ROOM_DISPLAY_NAME_LENGTH)
	var resolved_character_skin_id := _resolve_character_skin_id(String(message.get("character_skin_id", "")))
	var resolved_bubble_style_id := _resolve_bubble_style_id(String(message.get("bubble_style_id", "")))
	var resolved_bubble_skin_id := _resolve_bubble_skin_id(String(message.get("bubble_skin_id", "")))
	if not room_ticket_verifier.is_loadout_allowed(ticket_claim, requested_character_id, resolved_character_skin_id, resolved_bubble_style_id, resolved_bubble_skin_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED,
			"error": "ROOM_TICKET_LOADOUT_FORBIDDEN",
			"user_message": "Requested loadout is not allowed by room ticket",
		})
		return
	room_state.ensure_room(requested_room_id, peer_id, requested_room_kind, requested_room_display_name)
	_apply_ticket_claim_to_room_state(ticket_claim)
	room_state.set_selection(
		room_ticket_verifier.resolve_requested_map_id(message, ticket_claim),
		room_ticket_verifier.resolve_requested_rule_set_id(message, ticket_claim),
		room_ticket_verifier.resolve_requested_mode_id(message, ticket_claim)
	)
	room_state.upsert_member(
		peer_id,
		ticket_claim.display_name if not ticket_claim.display_name.is_empty() else String(message.get("player_name", "Player%d" % peer_id)),
		requested_character_id,
		resolved_character_skin_id,
		resolved_bubble_style_id,
		resolved_bubble_skin_id,
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
	_log_online_room_service("create_request_accepted", _build_online_service_context(ticket_claim, message))
	
	# Phase17: Send ROOM_MEMBER_SESSION for reconnect capability
	var binding := room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_MEMBER_SESSION,
			"room_id": room_state.room_id,
			"room_kind": room_state.room_kind,
			"room_display_name": room_state.room_display_name,
			"member_id": binding.member_id,
			"reconnect_token": binding.reconnect_token,
		})
	
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
		_log_online_room_service("join_request_matchmade_ticket_incompatible", _build_online_service_context(ticket_claim, message))
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
	var requested_character_id := String(message.get("character_id", "")).strip_edges()
	if requested_character_id.is_empty() or not CharacterCatalogScript.has_character(requested_character_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
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
	
	# Phase17: Reject normal join during active match
	if room_state.match_active:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "MATCH_ACTIVE_PLAYER_JOIN_FORBIDDEN",
			"user_message": "Active match is not joinable as a player",
		})
		return
	var resolved_character_skin_id := _resolve_character_skin_id(String(message.get("character_skin_id", "")))
	var resolved_bubble_style_id := _resolve_bubble_style_id(String(message.get("bubble_style_id", "")))
	var resolved_bubble_skin_id := _resolve_bubble_skin_id(String(message.get("bubble_skin_id", "")))
	if not room_ticket_verifier.is_loadout_allowed(ticket_claim, requested_character_id, resolved_character_skin_id, resolved_bubble_style_id, resolved_bubble_skin_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "ROOM_TICKET_LOADOUT_FORBIDDEN",
			"user_message": "Requested loadout is not allowed by room ticket",
		})
		return
	
	_apply_ticket_claim_to_room_state(ticket_claim)
	room_state.upsert_member(
		peer_id,
		ticket_claim.display_name if not ticket_claim.display_name.is_empty() else String(message.get("player_name", "Player%d" % peer_id)),
		requested_character_id,
		resolved_character_skin_id,
		resolved_bubble_style_id,
		resolved_bubble_skin_id,
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
	
	# Phase17: Send ROOM_MEMBER_SESSION for reconnect capability
	var binding := room_state.get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_MEMBER_SESSION,
			"room_id": room_state.room_id,
			"room_kind": room_state.room_kind,
			"room_display_name": room_state.room_display_name,
			"member_id": binding.member_id,
			"reconnect_token": binding.reconnect_token,
		})
	
	_broadcast_snapshot()
	_maybe_auto_start_match()
	_log_online_room_service("join_request_accepted", _build_online_service_context(ticket_claim, message))


func _handle_update_profile(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	var character_id := String(message.get("character_id", "")).strip_edges()
	var team_id := int(message.get("team_id", 1))
	if room_state.match_active:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_FORBIDDEN",
			"user_message": "Profile cannot be changed during an active match",
		})
		return
	if character_id.is_empty() or not CharacterCatalogScript.has_character(character_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
		})
		return
	if room_state.is_matchmade_room:
		var current_profile: Dictionary = room_state.members.get(peer_id, {})
		team_id = int(current_profile.get("team_id", team_id))
	if team_id < 1 or team_id > room_state.max_players:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Team selection is invalid",
		})
		return
	if bool(room_state.ready_map.get(peer_id, false)):
		var profile: Dictionary = room_state.members.get(peer_id, {})
		var current_team_id := int(profile.get("team_id", team_id))
		if team_id != current_team_id:
			send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
				"error": "ROOM_MEMBER_PROFILE_FORBIDDEN",
				"user_message": "Team cannot be changed after ready",
			})
			return
	room_state.update_profile(
		peer_id,
		String(message.get("player_name", "Player%d" % peer_id)),
		character_id,
		_resolve_character_skin_id(String(message.get("character_skin_id", ""))),
		_resolve_bubble_style_id(String(message.get("bubble_style_id", ""))),
		_resolve_bubble_skin_id(String(message.get("bubble_skin_id", ""))),
		team_id
	)
	_broadcast_snapshot()


func _handle_update_selection(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_state.is_matchmade_room:
		_log_online_room_service("update_selection_rejected_locked", _build_online_service_context(null, message))
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
	var rule_set_id := String(message.get("rule_set_id", ""))
	var mode_id := String(message.get("mode_id", ""))
	if not MapCatalogScript.has_map(map_id) or not RuleSetCatalogScript.has_rule(rule_set_id) or not ModeCatalogScript.has_mode(mode_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_SELECTION_INVALID",
			"user_message": "Map, rule, or mode selection is invalid",
		})
		return
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var mode_rule_set_id := String(mode_metadata.get("rule_set_id", ""))
	if not mode_rule_set_id.is_empty() and mode_rule_set_id != rule_set_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_SELECTION_INVALID",
			"user_message": "Mode does not match the selected rule set",
		})
		return
	room_state.set_selection(
		map_id,
		rule_set_id,
		mode_id
	)
	_broadcast_snapshot()


func _handle_toggle_ready(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_state.is_matchmade_room:
		_log_online_room_service("toggle_ready_rejected_locked", _build_online_service_context(null, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_READY_LOCKED",
			"user_message": "Matchmade room readiness is automatic",
		})
		return
	room_state.toggle_ready(peer_id)
	_broadcast_snapshot()
	_maybe_auto_start_match()


func _handle_start_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_state.is_matchmade_room:
		_log_online_room_service("start_request_rejected_locked", _build_online_service_context(null, message))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_LOCKED",
			"user_message": "Matchmade room starts automatically",
		})
		return
	if room_state.match_active:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "MATCH_ALREADY_ACTIVE",
			"user_message": "A match is already active",
		})
		return
	if room_state.get_distinct_team_ids().size() < 2:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_TEAM_INVALID",
			"user_message": "At least two teams are required to start",
		})
		return
	if peer_id != room_state.owner_peer_id or not room_state.can_start():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready to start",
		})
		return
	start_match_requested.emit(room_state.build_snapshot())


func _handle_leave_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var had_member := room_state != null and room_state.members.has(peer_id)
	if had_member:
		room_state.remove_member(peer_id)
		if room_state.members.is_empty():
			room_state.reset()
		_broadcast_snapshot()
	send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_LEAVE_ACCEPTED,
		"room_id": room_state.room_id,
		"had_member": had_member,
	})


func _handle_rematch_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_state.is_matchmade_room:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "MATCHMADE_REMATCH_FORBIDDEN",
			"user_message": "Matchmade rooms return to lobby after settlement",
		})
		return
	if peer_id != room_state.owner_peer_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "REMATCH_FORBIDDEN",
			"user_message": "Only the host can request a rematch",
		})
		return
	if room_state.room_id.is_empty():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Room does not exist",
		})
		return
	if room_state.match_active:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "MATCH_ALREADY_ACTIVE",
			"user_message": "A match is already active",
		})
		return
	if room_state.members.size() < room_state.min_start_players:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "ROOM_NOT_READY",
			"user_message": "Room is not ready for rematch (member count too low)",
		})
		return
	# Rematch follows the same formal start pipeline and only pre-fills readiness.
	for member_peer_id in room_state.members.keys():
		room_state.set_ready(member_peer_id, true)
	room_state.match_active = true
	_broadcast_snapshot()
	start_match_requested.emit(room_state.build_snapshot())


func _broadcast_snapshot() -> void:
	var snapshot := room_state.build_snapshot()
	room_snapshot_updated.emit(snapshot)
	broadcast_message.emit({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	})


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
	_log_online_room_service("assignment_commit_emitted", {
		"assignment_id": String(ticket_claim.assignment_id),
		"assignment_revision": int(ticket_claim.assignment_revision),
		"account_id": String(ticket_claim.account_id),
		"profile_id": String(ticket_claim.profile_id),
		"room_id": String(ticket_claim.room_id),
	})


func _maybe_auto_start_match() -> void:
	if room_state == null or not room_state.is_matchmade_room:
		return
	if room_state.match_active:
		_log_online_room_service("auto_start_skipped_match_active", _build_online_service_context())
		return
	if room_state.expected_member_count <= 0:
		_log_online_room_service("auto_start_skipped_missing_expected_count", _build_online_service_context())
		return
	if room_state.members.size() != room_state.expected_member_count:
		_log_online_room_service("auto_start_waiting_members", _build_online_service_context())
		return
	if not room_state.can_start():
		_log_online_room_service("auto_start_blocked_can_start_false", _build_online_service_context())
		return
	_log_online_room_service("auto_start_triggered", _build_online_service_context())
	start_match_requested.emit(room_state.build_snapshot())


func _resolve_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if CharacterSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


func _resolve_bubble_style_id(bubble_style_id: String) -> String:
	var trimmed := bubble_style_id.strip_edges()
	if BubbleCatalogScript.has_bubble(trimmed):
		return trimmed
	return BubbleCatalogScript.get_default_bubble_id()


func _resolve_bubble_skin_id(bubble_skin_id: String) -> String:
	var trimmed := bubble_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if BubbleSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


# Phase17: Resume request handling

func _handle_resume_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var ticket_validation = room_ticket_verifier.verify_resume_ticket(message) if room_ticket_verifier != null else null
	if ticket_validation == null or not bool(ticket_validation.ok):
		_reject_with_ticket_error(peer_id, TransportMessageTypesScript.ROOM_RESUME_REJECTED, ticket_validation)
		return
	var ticket_claim = ticket_validation.claim
	
	var requested_room_id := String(message.get("room_id", "")).strip_edges()
	var member_id := String(message.get("member_id", "")).strip_edges()
	var reconnect_token := String(message.get("reconnect_token", "")).strip_edges()
	var requested_match_id := String(message.get("match_id", "")).strip_edges()
	
	# Validate room
	if room_state.room_id.is_empty() or requested_room_id.is_empty() or room_state.room_id != requested_room_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Target room does not exist",
		})
		return
	
	# Validate member exists
	var binding := room_state.get_member_binding_by_member_id(member_id)
	if binding == null:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "MEMBER_NOT_FOUND",
			"user_message": "Member session not found",
		})
		return
	
	# Validate token
	if binding.reconnect_token != reconnect_token:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "RECONNECT_TOKEN_INVALID",
			"user_message": "Reconnect token is invalid",
		})
		return
	if binding.account_id != ticket_claim.account_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "ROOM_TICKET_ACCOUNT_MISMATCH",
			"user_message": "Room ticket account does not match member binding",
		})
		return
	if binding.profile_id != ticket_claim.profile_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "ROOM_TICKET_PROFILE_MISMATCH",
			"user_message": "Room ticket profile does not match member binding",
		})
		return
	
	# Check if resume window expired
	if binding.connection_state == "disconnected" and binding.disconnect_deadline_msec > 0:
		var current_time := Time.get_ticks_msec()
		if current_time > binding.disconnect_deadline_msec:
			send_to_peer.emit(peer_id, {
				"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
				"error": "RESUME_WINDOW_EXPIRED",
				"user_message": "Resume window has expired",
			})
			return
	
	# Mark as resuming
	binding.connection_state = "resuming"
	
	# If no active match, return to room
	if not room_state.match_active:
		var previous_peer_id := binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id
		room_state.bind_transport_to_member(member_id, peer_id)
		binding.connection_state = "connected"
		binding.match_peer_id = peer_id
		binding.disconnect_deadline_msec = 0
		binding.device_session_id = ticket_claim.device_session_id
		binding.ticket_id = ticket_claim.ticket_id
		binding.auth_claim_version = 1
		binding.display_name_source = "profile"
		if previous_peer_id > 0 and previous_peer_id != peer_id:
			room_state.members.erase(previous_peer_id)
			room_state.ready_map.erase(previous_peer_id)
			if room_state.owner_peer_id == previous_peer_id:
				room_state.owner_peer_id = peer_id
		var profile: Dictionary = room_state.members.get(peer_id, {})
		profile["peer_id"] = peer_id
		profile["player_name"] = binding.player_name
		profile["character_id"] = binding.character_id
		profile["character_skin_id"] = binding.character_skin_id
		profile["bubble_style_id"] = binding.bubble_style_id
		profile["bubble_skin_id"] = binding.bubble_skin_id
		profile["team_id"] = binding.team_id
		profile["ready"] = binding.ready
		room_state.members[peer_id] = profile
		room_state.ready_map[peer_id] = binding.ready
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_ACCEPTED,
			"room_id": room_state.room_id,
			"owner_peer_id": room_state.owner_peer_id,
		})
		_broadcast_snapshot()
		return
	
	# Active match exists - emit signal for ServerRoomRuntime to handle match resume
	# Transport rebinding is finalized by ServerMatchResumeCoordinator only after
	# it can build a valid battle resume payload.
	resume_request_received.emit({
		"sender_peer_id": peer_id,
		"member_id": member_id,
		"reconnect_token": reconnect_token,
		"match_id": requested_match_id,
		"ticket_claim": ticket_claim.to_dict(),
	})


func _reject_with_ticket_error(peer_id: int, message_type: String, validation_result) -> void:
	_log_online_room_service("ticket_validation_rejected", {
		"peer_id": peer_id,
		"message_type": message_type,
		"error_code": String(validation_result.error_code if validation_result != null else "ROOM_TICKET_INVALID"),
		"user_message": String(validation_result.user_message if validation_result != null else "Room ticket validation failed"),
	})
	send_to_peer.emit(peer_id, {
		"message_type": message_type,
		"error": String(validation_result.error_code if validation_result != null else "ROOM_TICKET_INVALID"),
		"user_message": String(validation_result.user_message if validation_result != null else "Room ticket validation failed"),
	})


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


func _log_online_room_service(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("%s[server_room_service] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "net.online.room_service")
