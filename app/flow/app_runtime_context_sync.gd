extends RefCounted


static func sync_front_context(runtime: Node) -> void:
	if runtime == null or runtime.front_context == null:
		return
	if runtime.has_method("_ensure_resume_state_store"):
		runtime._ensure_resume_state_store()
	runtime.front_context.auth_session_state = runtime.auth_session_state
	runtime.front_context.player_profile_state = runtime.player_profile_state
	runtime.front_context.front_settings_state = runtime.front_settings_state
	runtime.front_context.current_room_entry_context = runtime.current_room_entry_context
	runtime.front_context.pending_room_action = runtime.pending_room_action
	if runtime._resume_state_store != null and runtime._resume_state_store.has_method("sync_front_context"):
		runtime._resume_state_store.sync_front_context(runtime.front_context)
	else:
		runtime.front_context.current_loading_mode = runtime.current_loading_mode
		runtime.front_context.current_resume_snapshot = runtime.current_resume_snapshot


static func sync_battle_context(runtime: Node) -> void:
	if runtime == null or runtime.battle_context == null:
		return
	runtime.battle_context.current_room_snapshot = runtime.current_room_snapshot
	runtime.battle_context.current_start_config = runtime.current_start_config
	runtime.battle_context.current_battle_content_manifest = runtime.current_battle_content_manifest.duplicate(true)
	runtime.battle_context.current_battle_scene = runtime.current_battle_scene
	runtime.battle_context.current_battle_bootstrap = runtime.current_battle_bootstrap
	runtime.battle_context.current_presentation_bridge = runtime.current_presentation_bridge
	runtime.battle_context.current_battle_hud_controller = runtime.current_battle_hud_controller
	runtime.battle_context.current_battle_camera_controller = runtime.current_battle_camera_controller
	runtime.battle_context.current_settlement_controller = runtime.current_settlement_controller
	runtime.battle_context.current_settlement_popup_summary = runtime.current_settlement_popup_summary.duplicate(true)
