extends RefCounted


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
		controller._populate_match_format_selector(String(snapshot.queue_type))
		controller._select_metadata(controller.match_format_selector, String(snapshot.match_format_id))
		controller._populate_match_mode_multi_select(String(snapshot.queue_type), String(snapshot.match_format_id), snapshot.selected_match_mode_ids)
	else:
		controller._populate_mode_selector()
		controller._select_metadata(controller.game_mode_selector, String(view_model.get("selected_mode_id", "")))
		controller._populate_map_selector(String(view_model.get("selected_mode_id", "")))
		controller._select_metadata(controller.map_selector, String(view_model.get("selected_map_id", "")))
	controller._suppress_selection_callbacks = false
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
