extends RefCounted

const DEFAULT_MATCH_FORMAT_ID := "1v1"
const LogFrontScript = preload("res://app/logging/log_front.gd")


func refresh_room(controller: Node, snapshot: RoomSnapshot) -> void:
	if snapshot == null or controller._app_runtime == null or controller._room_view_model_builder == null or controller._room_scene_presenter == null:
		return
	var view_model : Dictionary = controller._room_view_model_builder.build_view_model(
		snapshot,
		controller._room_controller.room_runtime_context if controller._room_controller != null else null,
		controller._app_runtime.player_profile_state,
		controller._app_runtime.current_room_entry_context
	)
	controller._room_scene_presenter.present(view_model, controller)
	controller._room_scene_member_list_presenter.present(view_model.get("members", []), controller.member_list)
	controller._suppress_selection_callbacks = true
	controller._populate_team_selector(int(view_model.get("team_option_max", 2)))
	controller._select_team_id(int(view_model.get("local_team_id", 1)))
	if bool(view_model.get("is_match_room", false)):
		var resolved_match_format_id := String(snapshot.match_format_id).strip_edges()
		if resolved_match_format_id.is_empty():
			resolved_match_format_id = DEFAULT_MATCH_FORMAT_ID
		controller._populate_match_format_selector(String(snapshot.queue_type))
		controller._select_metadata(controller.match_format_selector, resolved_match_format_id)
		controller._populate_match_mode_multi_select(String(snapshot.queue_type), resolved_match_format_id, snapshot.selected_match_mode_ids)
	else:
		controller._populate_mode_selector()
		controller._select_metadata(controller.game_mode_selector, String(view_model.get("selected_mode_id", "")))
		controller._populate_map_selector(String(view_model.get("selected_mode_id", "")))
		controller._select_metadata(controller.map_selector, String(view_model.get("selected_map_id", "")))
	controller._suppress_selection_callbacks = false
	_log_room_scene("refresh_room", {
		"room_id": String(snapshot.room_id),
		"room_kind": String(snapshot.room_kind),
		"queue_type": String(snapshot.queue_type),
		"match_format_id": String(snapshot.match_format_id),
		"selected_match_mode_ids": snapshot.selected_match_mode_ids,
		"required_party_size": int(snapshot.required_party_size),
		"member_count": snapshot.members.size(),
		"all_ready": bool(snapshot.all_ready),
		"can_enter_queue": bool(view_model.get("can_enter_queue", false)),
		"can_ready": bool(view_model.get("can_ready", false)),
		"blocker_text": String(view_model.get("blocker_text", "")),
		"local_character_id": String(view_model.get("local_character_id", "")),
	})
	apply_room_kind_visibility(controller, view_model)
	refresh_match_room_controls(controller, snapshot, view_model)
	update_auth_binding_summary(controller, snapshot)
	update_preview(controller, snapshot)
	update_debug_text(controller, snapshot, view_model)


func update_preview(controller: Node, snapshot: RoomSnapshot) -> void:
	if controller._room_scene_view_binder == null:
		return
	var local_member := resolve_local_member(controller, snapshot)
	controller._room_scene_view_binder.update_preview(
		controller,
		snapshot,
		controller._app_runtime,
		local_member,
		controller._selected_team_id()
	)


func update_auth_binding_summary(controller: Node, snapshot: RoomSnapshot) -> void:
	if controller._room_scene_view_binder == null:
		return
	var local_member := resolve_local_member(controller, snapshot)
	controller._room_scene_view_binder.update_auth_binding_summary(controller, snapshot, controller._app_runtime, local_member)


func update_debug_text(controller: Node, snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if controller._room_scene_view_binder == null:
		return
	controller._room_scene_view_binder.update_debug_text(controller, snapshot, view_model)


func apply_room_kind_visibility(controller: Node, view_model: Dictionary) -> void:
	if controller._room_scene_view_binder == null:
		return
	controller._room_scene_view_binder.apply_room_kind_visibility(controller, view_model)


func refresh_match_room_controls(controller: Node, snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if controller._room_scene_view_binder == null:
		return
	controller._room_scene_view_binder.refresh_match_room_controls(controller, snapshot, view_model, controller._selected_match_mode_ids())


func resolve_local_member(controller: Node, snapshot: RoomSnapshot) -> RoomMemberState:
	if snapshot == null or controller._app_runtime == null:
		return null
	for member in snapshot.members:
		if member != null and member.peer_id == int(controller._app_runtime.local_peer_id):
			return member
	return null


func on_room_snapshot_changed(controller: Node, snapshot: RoomSnapshot) -> void:
	refresh_room(controller, snapshot)
	if snapshot != null and snapshot.battle_entry_ready and controller._room_use_case != null and controller._front_flow != null:
		var battle_ctx = controller._room_use_case.build_battle_entry_context(snapshot)
		if battle_ctx != null and controller._app_runtime != null:
			controller._app_runtime.current_battle_entry_context = battle_ctx
			if controller._front_flow.has_method("request_battle_entry"):
				controller._front_flow.request_battle_entry()


func _log_room_scene(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("[room_scene_snapshot] %s %s" % [event_name, JSON.stringify(payload)], "", 0, "front.room.scene.snapshot")
