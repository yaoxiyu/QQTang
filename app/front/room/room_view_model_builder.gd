class_name RoomViewModelBuilder
extends RefCounted


func build_view_model(
	snapshot: RoomSnapshot,
	room_runtime_context: RoomRuntimeContext,
	player_profile_state: PlayerProfileState,
	room_entry_context: RoomEntryContext
) -> Dictionary:
	var safe_snapshot := snapshot if snapshot != null else RoomSnapshot.new()
	var safe_context := room_runtime_context if room_runtime_context != null else RoomRuntimeContext.new()
	var safe_profile := player_profile_state if player_profile_state != null else PlayerProfileState.new()
	var safe_entry_context := room_entry_context if room_entry_context != null else RoomEntryContext.new()
	var resolved_room_kind := _resolve_room_kind(safe_snapshot, safe_context, safe_entry_context)
	var resolved_topology := _resolve_topology(safe_snapshot, safe_context, safe_entry_context)
	var resolved_room_display_name := _resolve_room_display_name(safe_snapshot, safe_entry_context)

	var local_peer_id := int(safe_context.local_player_id)
	var is_host := local_peer_id != 0 and local_peer_id == int(safe_snapshot.owner_peer_id)
	var is_practice := resolved_room_kind == "practice"
	var is_matchmade := resolved_room_kind == "matchmade_room"
	var member_count := safe_snapshot.member_count()
	var min_start_players := int(safe_snapshot.min_start_players if safe_snapshot.min_start_players > 0 else safe_context.min_start_players)
	if min_start_players <= 0:
		min_start_players = 2

	var blocker_text := _build_blocker_text(safe_snapshot, safe_context, safe_entry_context, is_host, member_count, min_start_players, is_practice)
	var owner_name := _resolve_owner_name(safe_snapshot, safe_profile)
	var connection_status_text := _build_connection_status_text(safe_snapshot, safe_context, safe_entry_context, is_practice)
	var members := _build_member_view_models(safe_snapshot.sorted_members())
	var has_server_pending_state := not is_practice and member_count <= 0
	var local_member_ready := _is_local_member_ready(members)
	var can_ready := local_peer_id > 0 and (not is_practice) and not has_server_pending_state and not is_matchmade
	var can_start := blocker_text.is_empty() and is_host and not is_matchmade
	var title_text := _build_title_text(resolved_room_kind, resolved_room_display_name)
	var lifecycle_status_text := _build_lifecycle_status_text(safe_context)
	var pending_action_status_text := _build_pending_action_status_text(safe_context, is_host)
	var reconnect_window_text := _build_reconnect_window_text(safe_snapshot)
	var active_match_resume_text := _build_active_match_resume_text(safe_snapshot)
	var local_team_id := _resolve_local_team_id(members)
	var team_option_max := int(safe_snapshot.max_players)
	if team_option_max <= 0:
		team_option_max = 1

	return {
		"title_text": title_text,
		"room_display_name": resolved_room_display_name,
		"room_id_text": _resolve_room_id_text(safe_snapshot, safe_entry_context, is_practice),
		"room_kind_text": _format_room_kind(resolved_room_kind),
		"topology_text": _format_topology(resolved_topology),
		"connection_status_text": connection_status_text,
		"owner_text": owner_name,
		"blocker_text": blocker_text,
		"lifecycle_status_text": lifecycle_status_text,
		"pending_action_status_text": pending_action_status_text,
		"reconnect_window_text": reconnect_window_text,
		"active_match_resume_text": active_match_resume_text,
		"can_edit_selection": is_host and not is_matchmade,
		"can_edit_team": (not local_member_ready) and not is_matchmade,
		"can_ready": can_ready,
		"can_start": can_start,
		"show_network_summary": not is_practice,
		"show_room_id": not is_practice,
		"show_connection_status": not is_practice,
		"show_add_opponent": is_practice,
		"local_member_ready": local_member_ready,
		"members": members,
		"selected_map_id": String(safe_snapshot.selected_map_id),
		"selected_rule_set_id": String(safe_snapshot.rule_set_id),
		"selected_mode_id": String(safe_snapshot.mode_id),
		"local_character_id": String(safe_profile.default_character_id),
		"local_character_skin_id": String(safe_profile.default_character_skin_id),
		"local_bubble_style_id": String(safe_profile.default_bubble_style_id),
		"local_bubble_skin_id": String(safe_profile.default_bubble_skin_id),
		"local_team_id": local_team_id,
		"team_option_max": team_option_max,
		"entry_kind": String(safe_entry_context.entry_kind),
		"return_target": String(safe_entry_context.return_target),
	}


func _resolve_room_kind(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext, room_entry_context: RoomEntryContext) -> String:
	if snapshot != null and not snapshot.room_kind.is_empty():
		return String(snapshot.room_kind)
	if room_runtime_context != null and not room_runtime_context.room_kind.is_empty():
		return String(room_runtime_context.room_kind)
	if room_entry_context != null and not room_entry_context.room_kind.is_empty():
		return String(room_entry_context.room_kind)
	return ""


func _resolve_topology(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext, room_entry_context: RoomEntryContext) -> String:
	if snapshot != null and not snapshot.topology.is_empty():
		return String(snapshot.topology)
	if room_runtime_context != null and not room_runtime_context.topology.is_empty():
		return String(room_runtime_context.topology)
	if room_entry_context != null and not room_entry_context.topology.is_empty():
		return String(room_entry_context.topology)
	return ""


func _resolve_room_display_name(snapshot: RoomSnapshot, room_entry_context: RoomEntryContext = null) -> String:
	if snapshot != null and not snapshot.room_display_name.is_empty():
		return String(snapshot.room_display_name)
	if room_entry_context != null and not room_entry_context.room_display_name.is_empty():
		return String(room_entry_context.room_display_name)
	return ""


func _build_title_text(room_kind: String, room_display_name: String) -> String:
	match room_kind:
		"practice":
			return "Practice Room"
		"matchmade_room":
			return "Matchmade Room"
		"public_room":
			if not room_display_name.is_empty():
				return "Public Room - %s" % room_display_name
			return "Public Room"
		"private_room":
			return "Private Room"
		_:
			return room_display_name if not room_display_name.is_empty() else room_kind


func _resolve_room_id_text(snapshot: RoomSnapshot, room_entry_context: RoomEntryContext, is_practice: bool) -> String:
	if is_practice:
		return "Practice Room"
	if snapshot != null and not snapshot.room_id.is_empty():
		return String(snapshot.room_id)
	if room_entry_context != null and not room_entry_context.target_room_id.is_empty():
		return String(room_entry_context.target_room_id)
	if room_entry_context != null and String(room_entry_context.entry_kind) == "online_create":
		return "Pending server assignment"
	return "Connecting..."


func _build_member_view_models(members: Array[RoomMemberState]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in members:
		if member == null:
			continue
		result.append({
			"peer_id": member.peer_id,
			"player_name": member.player_name,
			"ready": member.ready,
			"slot_index": member.slot_index,
			"character_id": member.character_id,
			"character_skin_id": member.character_skin_id,
			"bubble_style_id": member.bubble_style_id,
			"bubble_skin_id": member.bubble_skin_id,
			"team_id": member.team_id,
			"is_owner": member.is_owner,
			"is_local_player": member.is_local_player,
			"connection_state": member.connection_state,
		})
	return result


func _is_local_member_ready(members: Array[Dictionary]) -> bool:
	for entry in members:
		if not bool(entry.get("is_local_player", false)):
			continue
		return bool(entry.get("ready", false))
	return false


func _resolve_local_team_id(members: Array[Dictionary]) -> int:
	for entry in members:
		if bool(entry.get("is_local_player", false)):
			return int(entry.get("team_id", 1))
	return 1


func _build_blocker_text(
	snapshot: RoomSnapshot,
	room_runtime_context: RoomRuntimeContext,
	room_entry_context: RoomEntryContext,
	is_host: bool,
	member_count: int,
	min_start_players: int,
	is_practice: bool
) -> String:
	if snapshot == null:
		return "Room context is not ready"
	if room_runtime_context != null and not room_runtime_context.last_error.is_empty():
		return String(room_runtime_context.last_error.get("error_message", "Room connection failed"))
	var resolved_topology := _resolve_topology(snapshot, room_runtime_context, room_entry_context)
	if resolved_topology == "dedicated_server" and member_count <= 0:
		return "Connecting to dedicated server..."
	if not is_host:
		return "" if is_practice else "Waiting for host action"
	if snapshot.selected_map_id.is_empty() or snapshot.rule_set_id.is_empty() or snapshot.mode_id.is_empty():
		return "Selection is incomplete"
	if member_count < min_start_players:
		return "Need at least %d player(s)" % min_start_players
	if _count_distinct_team_ids(snapshot) < 2:
		return "At least two teams are required"
	if not snapshot.all_ready:
		return "All players must be ready"
	return ""


func _count_distinct_team_ids(snapshot: RoomSnapshot) -> int:
	var team_ids: Array[int] = []
	if snapshot == null:
		return 0
	for member in snapshot.members:
		if member == null or member.team_id < 1:
			continue
		if not team_ids.has(member.team_id):
			team_ids.append(member.team_id)
	return team_ids.size()


func _resolve_owner_name(snapshot: RoomSnapshot, player_profile_state: PlayerProfileState) -> String:
	if snapshot == null:
		return String(player_profile_state.nickname if player_profile_state != null else "")
	for member in snapshot.members:
		if member != null and member.peer_id == snapshot.owner_peer_id:
			return member.player_name
	if snapshot.owner_peer_id > 0:
		return "Peer %d" % int(snapshot.owner_peer_id)
	return String(player_profile_state.nickname if player_profile_state != null else "Pending")


func _build_connection_status_text(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext, room_entry_context: RoomEntryContext, is_practice: bool) -> String:
	if is_practice:
		return "Local"
	if snapshot == null:
		return "Disconnected"
	if room_runtime_context != null and not room_runtime_context.last_error.is_empty():
		return "Error"
	if snapshot.member_count() > 0:
		return "Connected"
	if room_entry_context != null and String(room_entry_context.topology) == "dedicated_server":
		return "Connecting"
	return "Disconnected"


func _format_room_kind(room_kind: String) -> String:
	match room_kind:
		"practice":
			return "Practice"
		"matchmade_room":
			return "Matchmade Room"
		"private_room":
			return "Private Room"
		"public_room":
			return "Public Room"
		_:
			return room_kind


func _format_topology(topology: String) -> String:
	match topology:
		"local":
			return "Local"
		"dedicated_server":
			return "Dedicated Server"
		_:
			return topology


func _build_lifecycle_status_text(room_runtime_context: RoomRuntimeContext) -> String:
	if room_runtime_context == null:
		return "Lifecycle: Unknown"
	var room_flow_name := RoomFlowState.state_to_string(int(room_runtime_context.room_flow_state))
	var session_name := SessionLifecycleState.state_to_string(int(room_runtime_context.session_lifecycle_state))
	var loading_suffix := ""
	if not String(room_runtime_context.loading_phase).is_empty():
		loading_suffix = " | loading=%s" % String(room_runtime_context.loading_phase)
	return "Lifecycle: %s / %s%s" % [room_flow_name, session_name, loading_suffix]


func _build_pending_action_status_text(room_runtime_context: RoomRuntimeContext, is_host: bool) -> String:
	if room_runtime_context == null:
		return "Pending: None"
	var pending_action := String(room_runtime_context.pending_room_action)
	if pending_action == "rematch":
		return "Pending: requesting rematch" if is_host else "Pending: waiting host rematch"
	if String(room_runtime_context.loading_phase) == "waiting":
		var ready_count := room_runtime_context.loading_ready_peers.size()
		var expected_count := room_runtime_context.loading_expected_peers.size()
		return "Pending: loading %d / %d ready" % [ready_count, expected_count]
	return "Pending: None"


func _build_reconnect_window_text(snapshot: RoomSnapshot) -> String:
	if snapshot == null or not bool(snapshot.match_active):
		return "Reconnect Window: -"
	var disconnected := PackedStringArray()
	for member in snapshot.members:
		if member == null:
			continue
		if String(member.connection_state) == "disconnected" or String(member.connection_state) == "resuming":
			disconnected.append(member.player_name)
	if disconnected.is_empty():
		return "Reconnect Window: none"
	return "Reconnect Window: %s" % ", ".join(disconnected)


func _build_active_match_resume_text(snapshot: RoomSnapshot) -> String:
	if snapshot == null or not bool(snapshot.match_active):
		return "Active Match Resume: inactive"
	var resuming_count := 0
	var disconnected_count := 0
	for member in snapshot.members:
		if member == null:
			continue
		if String(member.connection_state) == "resuming":
			resuming_count += 1
		elif String(member.connection_state) == "disconnected":
			disconnected_count += 1
	if resuming_count > 0:
		return "Active Match Resume: %d resuming" % resuming_count
	if disconnected_count > 0:
		return "Active Match Resume: %d disconnected" % disconnected_count
	return "Active Match Resume: all connected"
