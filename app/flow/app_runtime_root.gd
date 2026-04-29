extends Node

const ROOT_NODE_NAME: String = "AppRoot"
const LEGACY_ROOT_NODE_NAME: String = "AppRuntimeRoot"
const PENDING_RUNTIME_META_KEY: String = "_app_runtime_pending_instance"
const ROOM_SCENE_PATH := "res://scenes/front/room_scene.tscn"
const RuntimeLifecycleStateScript = preload("res://app/flow/runtime_lifecycle_state.gd")
const AppResumeStateStoreScript = preload("res://app/flow/app_resume_state_store.gd")
const AppNavigationCoordinatorScript = preload("res://app/flow/app_navigation_coordinator.gd")
const AppRuntimeInitializerScript = preload("res://app/flow/app_runtime_initializer.gd")
const AppRuntimeContextSyncScript = preload("res://app/flow/app_runtime_context_sync.gd")
const AppBattleModuleRegistryScript = preload("res://app/flow/app_battle_module_registry.gd")
const AppRuntimeNetworkBridgeScript = preload("res://app/flow/app_runtime_network_bridge.gd")
const DebugToolsScript = preload("res://app/debug/runtime_debug_tools.gd")
const NetworkErrorRouterScript = preload("res://network/runtime/network_error_router.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const SessionDiagnosticsScript = preload("res://network/runtime/session_diagnostics.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const FrontRuntimeContextScript = preload("res://app/flow/front_runtime_context.gd")
const BattleRuntimeContextScript = preload("res://app/flow/battle_runtime_context.gd")
const RuntimeShutdownCoordinatorScript = preload("res://app/runtime/runtime_shutdown_coordinator.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

signal runtime_state_changed(previous_state: int, next_state: int, reason: String)
signal runtime_ready()
signal runtime_disposing()
signal runtime_disposed()
signal runtime_error(error_code: String, message: String)

var local_peer_id: int = 1
var remote_peer_id: int = 2
var runtime_lifecycle_state: int = RuntimeLifecycleStateScript.Value.NONE
var _initialization_requested: bool = false
var _initialization_in_progress: bool = false
var _ready_emitted: bool = false
var _last_runtime_error_code: String = ""
var _last_runtime_error_message: String = ""

var front_flow: Node = null
var scene_flow: Node = null
var session_root: Node = null
var battle_root: Node = null
var debug_tools: Node = null
var room_session_controller: Node = null
var match_start_coordinator: Node = null
var battle_session_adapter: Node = null
var client_room_runtime: Node = null
var runtime_config: RefCounted = null
var error_router: RefCounted = NetworkErrorRouterScript.new()
var session_diagnostics: RefCounted = SessionDiagnosticsScript.new()
var last_runtime_error: Dictionary = {}
var front_context: RefCounted = FrontRuntimeContextScript.new()
var battle_context: RefCounted = BattleRuntimeContextScript.new()
var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var auth_session_repository: RefCounted = null
var auth_gateway: RefCounted = null
var profile_gateway: RefCounted = null
var wallet_gateway: RefCounted = null
var inventory_gateway: RefCounted = null
var shop_gateway: RefCounted = null
var room_ticket_gateway: RefCounted = null
var career_gateway: RefCounted = null
var settlement_gateway: RefCounted = null
var profile_repository: RefCounted = null
var front_settings_repository: RefCounted = null
var auth_session_restore_use_case: RefCounted = null
var register_use_case: RefCounted = null
var refresh_session_use_case: RefCounted = null
var logout_use_case: RefCounted = null
var login_use_case: RefCounted = null
var lobby_use_case: RefCounted = null
var lobby_directory_use_case: RefCounted = null
# LEGACY: kept as nullable compatibility slot; formal UI must not create or call MatchmakingUseCase.
var matchmaking_use_case: RefCounted = null
var career_use_case: RefCounted = null
var wallet_use_case: RefCounted = null
var inventory_use_case: RefCounted = null
var shop_use_case: RefCounted = null
var room_use_case: RefCounted = null
var settlement_sync_use_case: RefCounted = null
var practice_room_factory: RefCounted = null
var current_room_entry_context: RoomEntryContext = null
var loading_use_case: RefCounted = null
var pending_room_action: String = ""

var current_room_snapshot = null
var current_start_config = null
var current_battle_entry_context = null
var current_battle_content_manifest: Dictionary = {}
var current_battle_scene: Node = null
var current_battle_bootstrap: Node = null
var current_presentation_bridge: Node = null
var current_battle_hud_controller: Node = null
var current_battle_camera_controller: Node = null
var current_settlement_controller: Node = null
var current_settlement_popup_summary: Dictionary = {}
var _content_manifest_builder = BattleContentManifestBuilderScript.new()
var _shutdown_coordinator: RefCounted = RuntimeShutdownCoordinatorScript.new()
var _last_shutdown_metrics: Dictionary = {}

# Resume payload storage for room and battle return flow.
var current_resume_snapshot = null
var current_loading_mode: String = "normal_start"
var _resume_state_store: RefCounted = AppResumeStateStoreScript.new()

static func get_existing(tree: SceneTree):
	if tree == null or tree.root == null:
		return null
	if tree.root.has_node(ROOT_NODE_NAME):
		return tree.root.get_node(ROOT_NODE_NAME)
	if tree.root.has_node(LEGACY_ROOT_NODE_NAME):
		return tree.root.get_node(LEGACY_ROOT_NODE_NAME)
	if tree.root.has_meta(PENDING_RUNTIME_META_KEY):
		var pending = tree.root.get_meta(PENDING_RUNTIME_META_KEY)
		if is_instance_valid(pending):
			return pending
		tree.root.remove_meta(PENDING_RUNTIME_META_KEY)
	return null

static func ensure_in_tree(tree: SceneTree):
	if tree == null:
		return null
	var existing = get_existing(tree)
	if existing != null:
		if existing.name == LEGACY_ROOT_NODE_NAME:
			existing.name = ROOT_NODE_NAME
		if existing.has_method("request_initialize"):
			existing.request_initialize("ensure_in_tree_existing")
		elif existing.has_method("initialize_runtime"):
			existing.initialize_runtime()
		return existing
	if tree.root != null and tree.root.has_node(LEGACY_ROOT_NODE_NAME):
		var legacy_root := tree.root.get_node(LEGACY_ROOT_NODE_NAME)
		if legacy_root != null:
			legacy_root.name = ROOT_NODE_NAME
			if legacy_root.has_method("request_initialize"):
				legacy_root.request_initialize("ensure_in_tree_legacy")
			else:
				legacy_root.initialize_runtime()
			return legacy_root
	var runtime = load("res://app/flow/app_runtime_root.gd").new()
	runtime.name = ROOT_NODE_NAME
	runtime._set_runtime_state(RuntimeLifecycleStateScript.Value.ATTACH_PENDING, "ensure_in_tree_created")
	tree.root.set_meta(PENDING_RUNTIME_META_KEY, runtime)
	tree.root.add_child.call_deferred(runtime)
	runtime.request_initialize("ensure_in_tree")
	return runtime

func _ready() -> void:
	_clear_pending_runtime_meta()
	_shutdown_coordinator.register_handle(self)
	request_initialize("_ready")

func initialize_runtime() -> void:
	request_initialize("initialize_runtime")

func request_initialize(reason: String = "manual") -> void:
	_initialization_requested = true
	if is_runtime_ready() or runtime_lifecycle_state == RuntimeLifecycleStateScript.Value.DISPOSING or runtime_lifecycle_state == RuntimeLifecycleStateScript.Value.DISPOSED:
		return
	if _initialization_in_progress or runtime_lifecycle_state == RuntimeLifecycleStateScript.Value.INITIALIZING:
		return
	if not is_inside_tree():
		return
	name = ROOT_NODE_NAME
	_initialization_in_progress = true
	_set_runtime_state(RuntimeLifecycleStateScript.Value.INITIALIZING, reason)
	var init_result := AppRuntimeInitializerScript.request_initialize(self)
	if not bool(init_result.get("ok", false)):
		_initialization_in_progress = false
		_set_runtime_state(RuntimeLifecycleStateScript.Value.NONE, "initialize_failed")
		_on_network_error_routed({
			"error_code": String(init_result.get("error_code", "RUNTIME_INIT_FAILED")),
			"user_message": String(init_result.get("user_message", "Runtime initialization failed")),
			"message": String(init_result.get("user_message", "Runtime initialization failed")),
		})
		return
	_initialization_in_progress = false
	_set_runtime_state(RuntimeLifecycleStateScript.Value.READY, reason)
	if not _ready_emitted:
		_ready_emitted = true
		runtime_ready.emit()

func is_runtime_ready() -> bool:
	return runtime_lifecycle_state == RuntimeLifecycleStateScript.Value.READY

func is_runtime_initializing() -> bool:
	return _initialization_in_progress or runtime_lifecycle_state == RuntimeLifecycleStateScript.Value.INITIALIZING

func get_runtime_state_name() -> String:
	return RuntimeLifecycleStateScript.state_to_string(runtime_lifecycle_state)

func _set_runtime_state(next_state: int, reason: String) -> void:
	if runtime_lifecycle_state == next_state:
		return
	var previous_state := runtime_lifecycle_state
	runtime_lifecycle_state = next_state
	runtime_state_changed.emit(previous_state, next_state, reason)

func build_and_store_start_config(snapshot):
	if snapshot == null or match_start_coordinator == null:
		return null
	current_room_snapshot = snapshot.duplicate_deep()
	battle_context.current_room_snapshot = current_room_snapshot
	if error_router != null:
		error_router.clear_last_error(self)

	var prepare_result: Dictionary = match_start_coordinator.prepare_start_config(snapshot) if match_start_coordinator.has_method("prepare_start_config") else {}
	current_start_config = prepare_result.get("config", null)
	battle_context.current_start_config = current_start_config
	_update_current_battle_content_manifest()
	if not bool(prepare_result.get("ok", false)):
		if error_router != null:
			var validation: Dictionary = prepare_result.get("validation", {})
			var user_message := String(validation.get("error_message", "Failed to build battle start config"))
			if user_message.is_empty():
				user_message = "Failed to build battle start config"
			error_router.route_error(
				self,
				String(validation.get("error_code", NetworkErrorCodesScript.MATCH_CONFIG_BUILD_FAILED)),
				"match_start",
				"build_and_store_start_config",
				user_message,
				{
					"snapshot": snapshot.to_dict(),
					"validation": validation,
				},
				"return_to_room",
				true
			)
		return current_start_config
	if room_session_controller != null and current_start_config != null and not current_start_config.match_id.is_empty() and room_session_controller.has_method("set_pending_match_id"):
		room_session_controller.set_pending_match_id(current_start_config.match_id)
	if battle_session_adapter != null and current_start_config != null:
		battle_session_adapter.setup_from_start_config(current_start_config)
	return current_start_config

func clear_battle_payload() -> void:
	_log_online_runtime("clear_battle_payload", debug_dump_online_runtime_state())
	AppBattleModuleRegistryScript.clear_battle_payload(self)
	if battle_session_adapter != null:
		battle_session_adapter.setup_from_start_config(null)

func apply_canonical_start_config(config) -> void:
	current_start_config = config.duplicate_deep() if config != null else null
	battle_context.current_start_config = current_start_config
	_update_current_battle_content_manifest()
	if battle_session_adapter != null and current_start_config != null:
		battle_session_adapter.setup_from_start_config(current_start_config)
	_log_online_runtime("apply_canonical_start_config", debug_dump_online_runtime_state())

# Apply match resume payload.
func apply_match_resume_payload(config, resume_snapshot) -> void:
	apply_canonical_start_config(config)
	_ensure_resume_state_store()
	_resume_state_store.apply_match_resume_payload(resume_snapshot)
	_sync_resume_fields_from_store()
	_sync_front_context_from_fields()

# Clear resume payload.
func clear_resume_payload() -> void:
	AppBattleModuleRegistryScript.clear_resume_payload(self)

func set_local_peer_id(peer_id: int) -> void:
	if peer_id <= 0:
		return
	local_peer_id = peer_id
	if room_session_controller != null and room_session_controller.has_method("set_local_player_id"):
		room_session_controller.set_local_player_id(local_peer_id)

func register_battle_modules(
	battle_scene: Node,
	bootstrap: Node,
	bridge: Node,
	hud: Node,
	camera_controller: Node,
	settlement_controller: Node
) -> void:
	AppBattleModuleRegistryScript.register_modules(
		self,
		battle_scene,
		bootstrap,
		bridge,
		hud,
		camera_controller,
		settlement_controller
	)
	_log_online_runtime("register_battle_modules", debug_dump_online_runtime_state())

func unregister_battle_modules(battle_scene: Node) -> void:
	AppBattleModuleRegistryScript.unregister_modules(self, battle_scene)
	_log_online_runtime("unregister_battle_modules", debug_dump_online_runtime_state())

func debug_dump_online_runtime_state() -> Dictionary:
	return {
		"room_kind": String(current_room_entry_context.room_kind) if current_room_entry_context != null else "",
		"assignment_id": String(current_room_entry_context.assignment_id) if current_room_entry_context != null else "",
		"match_source": String(current_room_entry_context.match_source) if current_room_entry_context != null else "",
		"return_to_lobby_after_settlement": bool(current_room_entry_context.return_to_lobby_after_settlement) if current_room_entry_context != null else false,
		"room_id": String(current_room_entry_context.target_room_id) if current_room_entry_context != null else "",
		"match_id": String(current_start_config.match_id) if current_start_config != null else "",
		"battle_id": String(current_start_config.battle_id) if current_start_config != null else "",
		"authority_host": String(current_start_config.authority_host) if current_start_config != null else "",
		"authority_port": int(current_start_config.authority_port) if current_start_config != null else 0,
		"mode_id": String(current_start_config.mode_id) if current_start_config != null else "",
		"rule_set_id": String(current_start_config.rule_set_id) if current_start_config != null else "",
		"map_id": String(current_start_config.map_id) if current_start_config != null else "",
		"has_settlement_popup_summary": not current_settlement_popup_summary.is_empty(),
		"settlement_popup_summary": current_settlement_popup_summary.duplicate(true),
	}

func debug_dump_runtime_structure() -> Dictionary:
	if session_diagnostics == null:
		return {}
	return session_diagnostics.build_app_runtime_structure_dump(self)

func _on_network_error_routed(payload: Dictionary) -> void:
	AppRuntimeNetworkBridgeScript.on_network_error_routed(self, payload)

func _on_client_runtime_battle_message_received(message: Dictionary) -> void:
	AppRuntimeNetworkBridgeScript.on_client_runtime_battle_message_received(self, message)

func _on_client_runtime_transport_connected() -> void:
	AppRuntimeNetworkBridgeScript.on_client_runtime_transport_connected(self)

func _on_client_runtime_transport_disconnected() -> void:
	AppRuntimeNetworkBridgeScript.on_client_runtime_transport_disconnected(self)

func _on_client_runtime_room_error(error_code: String, user_message: String) -> void:
	AppRuntimeNetworkBridgeScript.on_client_runtime_room_error(self, error_code, user_message)

func _ensure_root_nodes() -> void:
	if session_root == null or not is_instance_valid(session_root):
		if has_node("SessionRoot"):
			session_root = get_node("SessionRoot")
		else:
			session_root = Node.new()
			session_root.name = "SessionRoot"
			add_child(session_root)

	if battle_root == null or not is_instance_valid(battle_root):
		if has_node("BattleRoot"):
			battle_root = get_node("BattleRoot")
		else:
			battle_root = Node.new()
			battle_root.name = "BattleRoot"
			add_child(battle_root)

	if debug_tools == null or not is_instance_valid(debug_tools):
		if has_node("DebugTools"):
			debug_tools = get_node("DebugTools")
		if debug_tools == null:
			debug_tools = DebugToolsScript.new()
			debug_tools.name = "DebugTools"
			add_child(debug_tools)

func _reparent_to(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	var old_parent := node.get_parent()
	if old_parent == new_parent:
		return
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)

func _update_current_battle_content_manifest() -> void:
	if current_start_config == null:
		current_battle_content_manifest = {}
		battle_context.current_battle_content_manifest = {}
		return
	current_battle_content_manifest = _content_manifest_builder.build_for_start_config(current_start_config)
	battle_context.current_battle_content_manifest = current_battle_content_manifest.duplicate(true)

func _ensure_resume_state_store() -> void:
	if _resume_state_store == null:
		_resume_state_store = AppResumeStateStoreScript.new()
	if _resume_state_store != null and _resume_state_store.has_method("set_state"):
		_resume_state_store.set_state(current_resume_snapshot, current_loading_mode)

func _sync_resume_fields_from_store() -> void:
	if _resume_state_store == null:
		return
	current_resume_snapshot = _resume_state_store.current_resume_snapshot
	current_loading_mode = _resume_state_store.current_loading_mode

func _sync_front_context_from_fields() -> void:
	AppRuntimeContextSyncScript.sync_front_context(self)

func _sync_battle_context_from_fields() -> void:
	AppRuntimeContextSyncScript.sync_battle_context(self)

func _exit_tree() -> void:
	_last_shutdown_metrics = _shutdown_coordinator.shutdown_all("app_runtime_exit", false)

func get_shutdown_name() -> String:
	return "app_runtime_root"

func get_shutdown_priority() -> int:
	return 40

func shutdown(_context: Variant) -> void:
	_clear_pending_runtime_meta()
	_initialization_in_progress = false
	_set_runtime_state(RuntimeLifecycleStateScript.Value.DISPOSING, "_exit_tree")
	runtime_disposing.emit()
	if room_use_case != null and room_use_case.has_method("dispose"):
		room_use_case.dispose()
	_set_runtime_state(RuntimeLifecycleStateScript.Value.DISPOSED, "_exit_tree")
	runtime_disposed.emit()

func get_shutdown_metrics() -> Dictionary:
	if not _last_shutdown_metrics.is_empty():
		return _last_shutdown_metrics.duplicate(true)
	return {
		"shutdown_failed": false,
		"runtime_state": runtime_lifecycle_state,
	}

func _clear_pending_runtime_meta() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not tree.root.has_meta(PENDING_RUNTIME_META_KEY):
		return
	var pending = tree.root.get_meta(PENDING_RUNTIME_META_KEY)
	if pending == self:
		tree.root.remove_meta(PENDING_RUNTIME_META_KEY)

func _try_load_script(path: String):
	if not ResourceLoader.exists(path):
		return null
	var script = load(path)
	return script

func _log_online_runtime(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[app_runtime_root] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.runtime.online")
