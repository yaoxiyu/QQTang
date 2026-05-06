extends RefCounted

const DEFAULT_MATCH_FORMAT_ID := "1v1"


func apply_local_profile_defaults(controller: Node) -> void:
	if controller._app_runtime == null or controller._app_runtime.player_profile_state == null:
		return
	var profile = controller._app_runtime.player_profile_state
	if controller.player_name_input != null:
		controller.player_name_input.text = profile.nickname
	controller._select_metadata(controller.character_selector, PlayerProfileState.resolve_default_character_id(String(profile.default_character_id)))
	controller._select_team_id(1)
	controller._select_metadata(controller.character_skin_selector, profile.default_character_skin_id)
	controller._select_metadata(controller.bubble_selector, profile.default_bubble_style_id)
	controller._select_metadata(controller.bubble_skin_selector, profile.default_bubble_skin_id)
	if String(profile.default_character_id).is_empty():
		profile.default_character_id = PlayerProfileState.resolve_default_character_id("")
		if controller._app_runtime.profile_repository != null and controller._app_runtime.profile_repository.has_method("save_profile"):
			controller._app_runtime.profile_repository.save_profile(profile)


func on_profile_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks or controller._room_use_case == null:
		return
	var snapshot: RoomSnapshot = controller._room_controller.build_room_snapshot() if controller._room_controller != null and controller._room_controller.has_method("build_room_snapshot") else null
	var local_member : RoomMemberState = controller._resolve_local_member(snapshot)
	if local_member != null and local_member.ready and controller._selected_team_id() != local_member.team_id:
		controller._select_team_id(local_member.team_id)
		controller._set_room_feedback("Team cannot be changed after ready")
		return
	if snapshot != null and controller.has_method("_update_preview"):
		controller._update_preview(snapshot)
	var result : Dictionary = controller._room_use_case.update_local_profile(
		controller.player_name_input.text.strip_edges() if controller.player_name_input != null else "",
		controller._selected_metadata(controller.character_selector),
		controller._selected_metadata(controller.character_skin_selector),
		controller._selected_metadata(controller.bubble_selector),
		controller._selected_metadata(controller.bubble_skin_selector),
		controller._selected_team_id()
	)
	if not bool(result.get("ok", false)):
		controller._set_room_feedback(String(result.get("user_message", "Failed to update profile")))


func on_profile_selector_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks:
		return
	on_profile_changed(controller)


func on_mode_selection_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks:
		return
	controller._suppress_selection_callbacks = true
	controller._populate_map_selector(controller._selected_metadata(controller.game_mode_selector))
	if controller.map_selector != null and controller.map_selector.item_count > 0:
		controller.map_selector.select(0)
	controller._suppress_selection_callbacks = false
	on_selection_changed(controller)


func on_selection_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks or controller._room_use_case == null:
		return
	var snapshot: RoomSnapshot = controller._room_controller.build_room_snapshot() if controller._room_controller != null and controller._room_controller.has_method("build_room_snapshot") else null
	var map_id : String = controller._selected_metadata(controller.map_selector)
	var binding : Dictionary = controller._resolve_map_binding(map_id)
	controller._log_room("room_selection_change_requested", {
		"old_map_id": String(snapshot.selected_map_id) if snapshot != null else "",
		"new_map_id": map_id,
		"derived_mode_id": String(binding.get("bound_mode_id", controller._selected_metadata(controller.game_mode_selector))),
		"derived_rule_set_id": String(binding.get("bound_rule_set_id", "")),
	})
	var result : Dictionary = controller._room_use_case.update_selection(
		map_id,
		String(binding.get("bound_rule_set_id", "")),
		String(binding.get("bound_mode_id", controller._selected_metadata(controller.game_mode_selector)))
	)
	if not bool(result.get("ok", false)):
		controller._set_room_feedback(String(result.get("user_message", "Failed to update room selection")))


func on_match_format_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks:
		return
	var snapshot: RoomSnapshot = controller._room_controller.build_room_snapshot() if controller._room_controller != null and controller._room_controller.has_method("build_room_snapshot") else null
	var queue_type := String(snapshot.queue_type) if snapshot != null else "casual"
	var match_format_id : String = _resolve_match_format_id(controller)
	controller._suppress_selection_callbacks = true
	controller._populate_match_mode_multi_select(queue_type, match_format_id)
	controller._suppress_selection_callbacks = false
	on_match_mode_multi_select_changed(controller)


func on_match_mode_multi_select_changed(controller: Node) -> void:
	if controller._suppress_selection_callbacks or controller._room_use_case == null:
		return
	var result : Dictionary = controller._room_use_case.update_match_room_config(
		_resolve_match_format_id(controller),
		controller._selected_match_mode_ids()
	)
	if not bool(result.get("ok", false)):
		controller._set_room_feedback(String(result.get("user_message", "Failed to update match room config")))


func _resolve_match_format_id(controller: Node) -> String:
	var match_format_id : String = controller._selected_metadata(controller.match_format_selector)
	if match_format_id.strip_edges().is_empty():
		return DEFAULT_MATCH_FORMAT_ID
	return match_format_id
