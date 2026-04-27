extends RefCounted


static func register_modules(
	runtime: Node,
	battle_scene: Node,
	battle_bootstrap: Node,
	presentation_bridge: Node,
	battle_hud_controller: Node,
	battle_camera_controller: Node,
	settlement_controller: Node
) -> void:
	if runtime == null:
		return
	runtime.current_battle_scene = battle_scene
	runtime.current_battle_bootstrap = battle_bootstrap
	runtime.current_presentation_bridge = presentation_bridge
	runtime.current_battle_hud_controller = battle_hud_controller
	runtime.current_battle_camera_controller = battle_camera_controller
	runtime.current_settlement_controller = settlement_controller
	if runtime.has_method("_sync_battle_context_from_fields"):
		runtime._sync_battle_context_from_fields()
	if battle_scene != null and runtime.battle_root != null and battle_scene.get_parent() != runtime.battle_root and runtime.has_method("_reparent_to"):
		if battle_scene.has_method("begin_runtime_reparent"):
			battle_scene.begin_runtime_reparent()
		runtime._reparent_to(battle_scene, runtime.battle_root)
		if battle_scene.has_method("end_runtime_reparent"):
			battle_scene.end_runtime_reparent()


static func unregister_modules(runtime: Node, battle_scene: Node) -> void:
	if runtime == null:
		return
	if battle_scene != null and runtime.current_battle_scene != battle_scene:
		return
	runtime.current_battle_scene = null
	runtime.current_battle_bootstrap = null
	runtime.current_presentation_bridge = null
	runtime.current_battle_hud_controller = null
	runtime.current_battle_camera_controller = null
	runtime.current_settlement_controller = null
	if runtime.has_method("_sync_battle_context_from_fields"):
		runtime._sync_battle_context_from_fields()


static func clear_battle_payload(runtime: Node) -> void:
	if runtime == null:
		return
	runtime.current_start_config = null
	runtime.current_battle_content_manifest = {}
	runtime.current_battle_scene = null
	runtime.current_battle_bootstrap = null
	runtime.current_presentation_bridge = null
	runtime.current_battle_hud_controller = null
	runtime.current_battle_camera_controller = null
	runtime.current_settlement_controller = null
	runtime.current_settlement_popup_summary = {}
	runtime.current_battle_entry_context = null
	if runtime.battle_context != null and runtime.battle_context.has_method("clear_battle_payload"):
		runtime.battle_context.clear_battle_payload()
	clear_resume_payload(runtime)


static func clear_resume_payload(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.has_method("_ensure_resume_state_store"):
		runtime._ensure_resume_state_store()
	if runtime._resume_state_store != null and runtime._resume_state_store.has_method("clear_resume_payload"):
		runtime._resume_state_store.clear_resume_payload()
	if runtime.has_method("_sync_resume_fields_from_store"):
		runtime._sync_resume_fields_from_store()
	if runtime.front_context != null and runtime.front_context.has_method("clear_resume_payload"):
		runtime.front_context.clear_resume_payload()
