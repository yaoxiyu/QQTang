class_name RoomViewModelBuilder
extends RefCounted

const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")


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
	var is_host := _is_local_host(safe_snapshot, local_peer_id)
	var is_practice := resolved_room_kind == "practice"
	var is_custom_room := FrontRoomKind.is_custom_room(resolved_room_kind)
	var is_match_room := FrontRoomKind.is_match_room(resolved_room_kind)
	var is_assigned_room := FrontRoomKind.is_assigned_room(resolved_room_kind)
	var member_count := safe_snapshot.member_count()
	var min_start_players := int(safe_snapshot.min_start_players if safe_snapshot.min_start_players > 0 else safe_context.min_start_players)
	if min_start_players <= 0:
		min_start_players = 2

	var blocker_text := _build_blocker_text(safe_snapshot, safe_context, safe_entry_context, is_host, member_count, min_start_players, is_practice, is_match_room)
	var owner_name := _resolve_owner_name(safe_snapshot, safe_profile)
	var connection_status_text := _build_connection_status_text(safe_snapshot, safe_context, safe_entry_context, is_practice)
	var members := _build_member_view_models(safe_snapshot.sorted_members())
	var has_server_pending_state := not is_practice and member_count <= 0
	var local_member_ready := _is_local_member_ready(members)
	var can_ready := bool(safe_snapshot.can_toggle_ready)
	var can_start := bool(safe_snapshot.can_start_manual_battle)
	var title_text := _build_title_text(resolved_room_kind, resolved_room_display_name)
	var lifecycle_status_text := _build_lifecycle_status_text(safe_context)
	var pending_action_status_text := _build_pending_action_status_text(safe_context, is_host)
	var reconnect_window_text := _build_reconnect_window_text(safe_snapshot)
	var active_match_resume_text := _build_active_match_resume_text(safe_snapshot)
	var local_team_id := _resolve_local_team_id(members)
	var binding := _resolve_map_binding(String(safe_snapshot.selected_map_id))
	var required_team_count := int(binding.get("required_team_count", min_start_players))
	if required_team_count <= 0:
		required_team_count = max(1, min_start_players)
	var max_player_count := int(binding.get("max_player_count", safe_snapshot.max_players))
	if max_player_count <= 0:
		max_player_count = safe_snapshot.max_players
	var can_edit_selection := bool(safe_snapshot.can_update_selection)
	var can_edit_match_room_config := bool(safe_snapshot.can_update_match_room_config)
	var can_enter_queue := bool(safe_snapshot.can_enter_queue)
	var can_cancel_queue := bool(safe_snapshot.can_cancel_queue)
	var rule_display_name := String(binding.get("rule_set_name", safe_snapshot.rule_set_id))
	var mode_display_name := String(binding.get("mode_name", safe_snapshot.mode_id))
	var eligible_map_pool_hint_text := _build_eligible_map_pool_hint_text(safe_snapshot) if is_match_room else ""

	return {
		"title_text": title_text,
		"room_kind": resolved_room_kind,
		"is_custom_room": is_custom_room,
		"is_match_room": is_match_room,
		"is_assigned_room": is_assigned_room,
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
		"can_edit_selection": can_edit_selection,
		"can_edit_team": (not local_member_ready) and is_custom_room,
		"can_ready": can_ready,
		"can_start": can_start,
		"show_match_format_selector": is_match_room,
		"show_match_mode_multi_select": is_match_room,
		"show_queue_buttons": is_match_room,
		"show_invite_row": is_match_room,
		"show_team_selector": is_custom_room,
		"can_edit_match_room_config": can_edit_match_room_config,
		"can_enter_queue": can_enter_queue,
		"can_cancel_queue": can_cancel_queue,
		"match_room_party_status_text": _build_match_room_party_status_text(safe_snapshot, member_count) if is_match_room else "",
		"eligible_map_pool_hint_text": eligible_map_pool_hint_text,
		"invite_code_text": String(safe_snapshot.room_id),
		"queue_status_text": _build_queue_status_text(safe_snapshot),
		"queue_error_text": _build_queue_error_text(safe_snapshot),
		"show_network_summary": not is_practice,
		"show_room_id": not is_practice,
		"show_connection_status": not is_practice,
		"show_add_opponent": is_practice,
		"local_member_ready": local_member_ready,
		"members": members,
		"selected_map_id": String(safe_snapshot.selected_map_id),
		"selected_rule_set_id": String(safe_snapshot.rule_set_id),
		"selected_mode_id": String(safe_snapshot.mode_id),
		"selected_rule_display_name": rule_display_name,
		"selected_mode_display_name": mode_display_name,
		"local_character_id": String(safe_profile.default_character_id),
		"local_character_skin_id": String(safe_profile.default_character_skin_id),
		"local_bubble_style_id": String(safe_profile.default_bubble_style_id),
		"local_bubble_skin_id": String(safe_profile.default_bubble_skin_id),
		"local_team_id": local_team_id,
		"team_option_max": required_team_count,
		"required_team_count": required_team_count,
		"max_player_count": max_player_count,
		"entry_kind": String(safe_entry_context.entry_kind),
		"return_target": String(safe_entry_context.return_target),
		# Battle allocation state.
		"room_phase": String(safe_snapshot.room_phase),
		"queue_phase": String(safe_snapshot.queue_phase),
		"queue_terminal_reason": String(safe_snapshot.queue_terminal_reason),
		"room_lifecycle_state": String(safe_snapshot.room_lifecycle_state),
		"battle_phase": String(safe_snapshot.battle_phase),
		"battle_terminal_reason": String(safe_snapshot.battle_terminal_reason),
		"battle_allocation_state": String(safe_snapshot.battle_allocation_state),
		"battle_entry_ready": bool(safe_snapshot.battle_entry_ready),
		"current_assignment_id": String(safe_snapshot.current_assignment_id),
		"current_battle_id": String(safe_snapshot.current_battle_id),
		"battle_server_host": String(safe_snapshot.battle_server_host),
		"battle_server_port": int(safe_snapshot.battle_server_port),
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
		"casual_match_room":
			return "Casual Match Room"
		"ranked_match_room":
			return "Ranked Match Room"
		"custom_room":
			if not room_display_name.is_empty():
				return "Custom Room - %s" % room_display_name
			return "Custom Room"
		"public_room":
			if not room_display_name.is_empty():
				return "Custom Room - %s" % room_display_name
			return "Custom Room"
		"private_room":
			return "Custom Room"
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


func _is_local_host(snapshot: RoomSnapshot, local_peer_id: int) -> bool:
	if snapshot == null:
		return false
	for member in snapshot.members:
		if member != null and member.is_local_player and member.is_owner:
			return true
	return local_peer_id > 0 and local_peer_id == int(snapshot.owner_peer_id)


func _build_blocker_text(
	snapshot: RoomSnapshot,
	room_runtime_context: RoomRuntimeContext,
	room_entry_context: RoomEntryContext,
	is_host: bool,
	member_count: int,
	min_start_players: int,
	is_practice: bool,
	is_match_room: bool
) -> String:
	if snapshot == null:
		return "Room context is not ready"
	if room_runtime_context != null and not room_runtime_context.last_error.is_empty() and member_count <= 0:
		return String(room_runtime_context.last_error.get("error_message", "Room connection failed"))
	var resolved_topology := _resolve_topology(snapshot, room_runtime_context, room_entry_context)
	if resolved_topology == "dedicated_server" and member_count <= 0:
		return "Connecting to dedicated server..."
	if not is_host:
		return "" if is_practice else "Waiting for host action"
	if is_match_room:
		return _build_match_room_blocker_text(snapshot, member_count)
	if String(snapshot.room_phase) != "" and String(snapshot.room_phase) != "idle":
		return "当前阶段不可开始对局"
	if snapshot.selected_map_id.is_empty() or snapshot.rule_set_id.is_empty() or snapshot.mode_id.is_empty():
		return "Selection is incomplete"
	var binding := _resolve_map_binding(String(snapshot.selected_map_id))
	if binding.is_empty():
		return "Selection is incomplete"
	var required_team_count := int(binding.get("required_team_count", min_start_players))
	var max_player_count := int(binding.get("max_player_count", snapshot.max_players))
	if max_player_count > 0 and member_count > max_player_count:
		return "Room is over capacity"
	if member_count < min_start_players:
		return "Need at least %d player(s)" % min_start_players
	if _count_distinct_team_ids(snapshot) < required_team_count:
		return "Need at least %d teams" % required_team_count
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
		"casual_match_room":
			return "Casual Match Room"
		"ranked_match_room":
			return "Ranked Match Room"
		"custom_room":
			return "Custom Room"
		"private_room":
			return "Custom Room (Private)"
		"public_room":
			return "Custom Room (Public)"
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


func _resolve_map_binding(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return {}
	return binding


func _build_match_room_blocker_text(snapshot: RoomSnapshot, member_count: int) -> String:
	if snapshot == null:
		return "Room context is not ready"
	var room_phase := String(snapshot.room_phase)
	if room_phase.is_empty():
		room_phase = String(snapshot.room_lifecycle_state)
	if room_phase != "idle":
		return "当前阶段不可开始匹配"
	var required_party_size := _resolve_required_party_size(snapshot)
	if member_count != required_party_size:
		return "队伍人数需要满足 %d 人编队" % required_party_size
	if snapshot.selected_match_mode_ids.is_empty() and String(snapshot.mode_id).is_empty():
		return "请选择匹配模式"
	if not bool(snapshot.all_ready):
		return "所有成员需要准备"
	return ""


func _build_match_room_party_status_text(snapshot: RoomSnapshot, member_count: int) -> String:
	if snapshot == null:
		return "队伍状态：未知"
	var required_party_size := _resolve_required_party_size(snapshot)
	return "队伍人数：%d / %d" % [member_count, required_party_size]


func _resolve_required_party_size(snapshot: RoomSnapshot) -> int:
	if snapshot == null:
		return 1
	match String(snapshot.match_format_id).strip_edges():
		"1v1":
			return 1
		"2v2":
			return 2
		"4v4":
			return 4
		_:
			var fallback := int(snapshot.required_party_size)
			return fallback if fallback > 0 else 1


func _build_eligible_map_pool_hint_text(snapshot: RoomSnapshot) -> String:
	if snapshot == null:
		return ""
	var queue_type := String(snapshot.queue_type)
	var match_format_id := String(snapshot.match_format_id)
	var selected_mode_ids := snapshot.selected_match_mode_ids
	if selected_mode_ids.is_empty() and not String(snapshot.mode_id).is_empty():
		selected_mode_ids = [String(snapshot.mode_id)]
	var count := MapSelectionCatalogScript.get_match_room_eligible_map_count(queue_type, match_format_id, selected_mode_ids)
	if count <= 0:
		if match_format_id == "4v4":
			return "4v4 当前暂无可运营地图"
		return "当前选择没有合法地图"
	return "当前模式池可匹配 %d 张地图" % count


func _build_queue_status_text(snapshot: RoomSnapshot) -> String:
	if snapshot == null:
		return ""
	if not String(snapshot.queue_status_text).is_empty():
		return String(snapshot.queue_status_text)
	var queue_phase := String(snapshot.queue_phase)
	var queue_terminal_reason := String(snapshot.queue_terminal_reason)
	if queue_phase.is_empty():
		return _build_match_room_party_status_text(snapshot, snapshot.member_count())
	match queue_phase:
		"queued":
			return "匹配中"
		"assignment_pending":
			return "已匹配，等待对局分配"
		"allocating_battle":
			return "正在分配对局服务器"
		"entry_ready":
			return "对局已就绪，正在进入"
		"completed":
			match queue_terminal_reason:
				"client_cancelled":
					return "已取消匹配"
				"assignment_expired":
					return "匹配已过期"
				"allocation_failed":
					return "分配失败"
				"match_finalized":
					return "对局已完成"
				_:
					return "匹配流程已结束"
		_:
			return _build_match_room_party_status_text(snapshot, snapshot.member_count())


func _build_queue_error_text(snapshot: RoomSnapshot) -> String:
	if snapshot == null:
		return ""
	if not String(snapshot.queue_user_message).is_empty():
		return String(snapshot.queue_user_message)
	if not String(snapshot.queue_error_code).is_empty():
		return String(snapshot.queue_error_code)
	if not String(snapshot.room_queue_error_message).is_empty():
		return String(snapshot.room_queue_error_message)
	if not String(snapshot.room_queue_error_code).is_empty():
		return String(snapshot.room_queue_error_code)
	return ""
