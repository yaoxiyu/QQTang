extends Node

const ROOT_NODE_NAME: String = "AppRoot"
const LEGACY_ROOT_NODE_NAME: String = "AppRuntimeRoot"
const PENDING_RUNTIME_META_KEY: String = "_app_runtime_pending_instance"
const ROOM_SCENE_PATH := "res://scenes/front/room_scene.tscn"
const RuntimeLifecycleStateScript = preload("res://app/flow/runtime_lifecycle_state.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const AuthSessionRepositoryScript = preload("res://app/front/auth/auth_session_repository.gd")
const LocalAuthSessionRepositoryScript = preload("res://app/front/auth/local_auth_session_repository.gd")
const HttpAuthGatewayScript = preload("res://app/front/auth/http_auth_gateway.gd")
const HttpRoomTicketGatewayScript = preload("res://app/front/auth/http_room_ticket_gateway.gd")
const LoginUseCaseScript = preload("res://app/front/auth/login_use_case.gd")
const PassThroughAuthGatewayScript = preload("res://app/front/auth/pass_through_auth_gateway.gd")
const LobbyUseCaseScript = preload("res://app/front/lobby/lobby_use_case.gd")
const LobbyDirectoryUseCaseScript = preload("res://app/front/lobby/lobby_directory_use_case.gd")
const MatchmakingUseCaseScript = preload("res://app/front/matchmaking/matchmaking_use_case.gd")
const HttpMatchmakingGatewayScript = preload("res://app/front/matchmaking/http_matchmaking_gateway.gd")
const PracticeRoomFactoryScript = preload("res://app/front/lobby/practice_room_factory.gd")
const CareerUseCaseScript = preload("res://app/front/career/career_use_case.gd")
const HttpCareerGatewayScript = preload("res://app/front/career/http_career_gateway.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const FrontSettingsRepositoryScript = preload("res://app/front/profile/front_settings_repository.gd")
const HttpProfileGatewayScript = preload("res://app/front/profile/http_profile_gateway.gd")
const LocalFrontSettingsRepositoryScript = preload("res://app/front/profile/local_front_settings_repository.gd")
const LocalProfileRepositoryScript = preload("res://app/front/profile/local_profile_repository.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const ProfileRepositoryScript = preload("res://app/front/profile/profile_repository.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")
const SettlementSyncUseCaseScript = preload("res://app/front/settlement/settlement_sync_use_case.gd")
const HttpSettlementGatewayScript = preload("res://app/front/settlement/http_settlement_gateway.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const DebugToolsScript = preload("res://app/debug/runtime_debug_tools.gd")
const AppRuntimeConfigScript = preload("res://app/flow/app_runtime_config.gd")
const ClientRoomRuntimeScript = preload("res://network/runtime/client_room_runtime.gd")
const NetworkErrorRouterScript = preload("res://network/runtime/network_error_router.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const SessionDiagnosticsScript = preload("res://network/runtime/session_diagnostics.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const LoadingUseCaseScript = preload("res://app/front/loading/loading_use_case.gd")
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
var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var auth_session_repository: RefCounted = null
var auth_gateway: RefCounted = null
var profile_gateway: RefCounted = null
var room_ticket_gateway: RefCounted = null
var matchmaking_gateway: RefCounted = null
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
var matchmaking_use_case: RefCounted = null
var career_use_case: RefCounted = null
var room_use_case: RefCounted = null
var settlement_sync_use_case: RefCounted = null
var practice_room_factory: RefCounted = null
var current_room_entry_context: RoomEntryContext = null
var loading_use_case: RefCounted = null
var pending_room_action: String = ""

var current_room_snapshot = null
var current_start_config = null
var current_battle_content_manifest: Dictionary = {}
var current_battle_scene: Node = null
var current_battle_bootstrap: Node = null
var current_presentation_bridge: Node = null
var current_battle_hud_controller: Node = null
var current_battle_camera_controller: Node = null
var current_settlement_controller: Node = null
var current_settlement_popup_summary: Dictionary = {}
var _content_manifest_builder = BattleContentManifestBuilderScript.new()

# Phase17: Resume payload storage
var current_resume_snapshot = null
var current_loading_mode: String = "normal_start"


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
	_ensure_root_nodes()
	_ensure_runtime_config()
	_ensure_front_repositories()
	_ensure_front_local_state()
	_ensure_front_services()

	if front_flow == null or not is_instance_valid(front_flow):
		front_flow = FrontFlowControllerScript.new()
		front_flow.name = "FrontFlowController"
		add_child(front_flow)

	if scene_flow == null or not is_instance_valid(scene_flow):
		scene_flow = SceneFlowControllerScript.new()
		scene_flow.name = "SceneFlowController"
		add_child(scene_flow)

	front_flow.configure(scene_flow)

	if room_session_controller == null or not is_instance_valid(room_session_controller):
		room_session_controller = RoomSessionControllerScript.new()
		room_session_controller.name = "RoomSessionController"
		session_root.add_child(room_session_controller)
	elif room_session_controller.get_parent() != session_root:
		_reparent_to(room_session_controller, session_root)
	if room_session_controller != null and room_session_controller.has_method("set_local_player_id"):
		room_session_controller.set_local_player_id(local_peer_id)
	if practice_room_factory != null and practice_room_factory.has_method("configure"):
		practice_room_factory.configure(room_session_controller)

	if match_start_coordinator == null or not is_instance_valid(match_start_coordinator):
		match_start_coordinator = MatchStartCoordinatorScript.new()
		match_start_coordinator.name = "MatchStartCoordinator"
		session_root.add_child(match_start_coordinator)
	elif match_start_coordinator.get_parent() != session_root:
		_reparent_to(match_start_coordinator, session_root)

	if battle_session_adapter == null or not is_instance_valid(battle_session_adapter):
		battle_session_adapter = BattleSessionAdapterScript.new()
		battle_session_adapter.name = "BattleSessionAdapter"
		session_root.add_child(battle_session_adapter)
	elif battle_session_adapter.get_parent() != session_root:
		_reparent_to(battle_session_adapter, session_root)

	if client_room_runtime == null or not is_instance_valid(client_room_runtime):
		client_room_runtime = ClientRoomRuntimeScript.new()
		client_room_runtime.name = "ClientRoomRuntime"
		session_root.add_child(client_room_runtime)
	elif client_room_runtime.get_parent() != session_root:
		_reparent_to(client_room_runtime, session_root)
	if client_room_runtime != null and battle_session_adapter != null and not client_room_runtime.battle_message_received.is_connected(_on_client_runtime_battle_message_received):
		client_room_runtime.battle_message_received.connect(_on_client_runtime_battle_message_received)
	if client_room_runtime != null and battle_session_adapter != null and not client_room_runtime.transport_connected.is_connected(_on_client_runtime_transport_connected):
		client_room_runtime.transport_connected.connect(_on_client_runtime_transport_connected)
	if client_room_runtime != null and battle_session_adapter != null and not client_room_runtime.transport_disconnected.is_connected(_on_client_runtime_transport_disconnected):
		client_room_runtime.transport_disconnected.connect(_on_client_runtime_transport_disconnected)
	if client_room_runtime != null and battle_session_adapter != null and not client_room_runtime.room_error.is_connected(_on_client_runtime_room_error):
		client_room_runtime.room_error.connect(_on_client_runtime_room_error)

	_ensure_front_use_cases()

	if scene_flow.current_scene_path.is_empty():
		scene_flow.current_scene_path = SceneFlowControllerScript.BOOT_SCENE_PATH
	if int(front_flow.current_state) != int(FrontFlowControllerScript.FlowState.BOOT):
		front_flow.current_state = FrontFlowControllerScript.FlowState.BOOT
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
	if error_router != null:
		error_router.clear_last_error(self)

	var prepare_result: Dictionary = match_start_coordinator.prepare_start_config(snapshot) if match_start_coordinator.has_method("prepare_start_config") else {}
	current_start_config = prepare_result.get("config", null)
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
	current_start_config = null
	current_battle_content_manifest = {}
	current_battle_scene = null
	current_battle_bootstrap = null
	current_presentation_bridge = null
	current_battle_hud_controller = null
	current_battle_camera_controller = null
	current_settlement_controller = null
	current_settlement_popup_summary = {}
	# Phase17: Clear resume payload
	current_resume_snapshot = null
	current_loading_mode = "normal_start"
	if battle_session_adapter != null:
		battle_session_adapter.setup_from_start_config(null)


func apply_canonical_start_config(config) -> void:
	current_start_config = config.duplicate_deep() if config != null else null
	_update_current_battle_content_manifest()
	if battle_session_adapter != null and current_start_config != null:
		battle_session_adapter.setup_from_start_config(current_start_config)
	_log_online_runtime("apply_canonical_start_config", debug_dump_online_runtime_state())


# Phase17: Apply match resume payload
func apply_match_resume_payload(config, resume_snapshot) -> void:
	apply_canonical_start_config(config)
	current_resume_snapshot = resume_snapshot
	current_loading_mode = "resume_match"


# Phase17: Clear resume payload
func clear_resume_payload() -> void:
	current_resume_snapshot = null
	current_loading_mode = "normal_start"


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
	current_battle_scene = battle_scene
	current_battle_bootstrap = bootstrap
	current_presentation_bridge = bridge
	current_battle_hud_controller = hud
	current_battle_camera_controller = camera_controller
	current_settlement_controller = settlement_controller
	if battle_scene != null and battle_root != null and battle_scene.get_parent() != battle_root:
		_reparent_to(battle_scene, battle_root)
	_log_online_runtime("register_battle_modules", debug_dump_online_runtime_state())


func unregister_battle_modules(battle_scene: Node) -> void:
	if battle_scene != null and current_battle_scene != battle_scene:
		return
	current_battle_scene = null
	current_battle_bootstrap = null
	current_presentation_bridge = null
	current_battle_hud_controller = null
	current_battle_camera_controller = null
	current_settlement_controller = null
	_log_online_runtime("unregister_battle_modules", debug_dump_online_runtime_state())


func debug_dump_online_runtime_state() -> Dictionary:
	return {
		"room_kind": String(current_room_entry_context.room_kind) if current_room_entry_context != null else "",
		"assignment_id": String(current_room_entry_context.assignment_id) if current_room_entry_context != null else "",
		"match_source": String(current_room_entry_context.match_source) if current_room_entry_context != null else "",
		"return_to_lobby_after_settlement": bool(current_room_entry_context.return_to_lobby_after_settlement) if current_room_entry_context != null else false,
		"room_id": String(current_room_entry_context.target_room_id) if current_room_entry_context != null else "",
		"match_id": String(current_start_config.match_id) if current_start_config != null else "",
		"mode_id": String(current_start_config.mode_id) if current_start_config != null else "",
		"rule_set_id": String(current_start_config.rule_set_id) if current_start_config != null else "",
		"map_id": String(current_start_config.map_id) if current_start_config != null else "",
		"has_settlement_popup_summary": not current_settlement_popup_summary.is_empty(),
		"settlement_popup_summary": current_settlement_popup_summary.duplicate(true),
	}


func debug_dump_runtime_structure() -> Dictionary:
	var diagnostics_dump: Dictionary = session_diagnostics.build_runtime_dump(self) if session_diagnostics != null else {}
	return {
		"root_name": name,
		"runtime_state": runtime_lifecycle_state,
		"runtime_state_name": get_runtime_state_name(),
		"runtime_ready": is_runtime_ready(),
		"runtime_initialization_requested": _initialization_requested,
		"runtime_initialization_in_progress": _initialization_in_progress,
		"has_session_root": session_root != null,
		"has_battle_root": battle_root != null,
		"has_debug_tools": debug_tools != null,
		"has_runtime_config": runtime_config != null,
		"runtime_config": runtime_config.to_dict() if runtime_config != null else {},
		"has_active_battle_scene": current_battle_scene != null,
		"has_active_battle_bootstrap": current_battle_bootstrap != null,
		"has_active_presentation_bridge": current_presentation_bridge != null,
		"has_active_battle_hud": current_battle_hud_controller != null,
		"has_active_battle_camera": current_battle_camera_controller != null,
		"has_active_settlement": current_settlement_controller != null,
		"current_battle_content_manifest": current_battle_content_manifest.duplicate(true),
		"battle_root_children": battle_root.get_child_count() if battle_root != null else 0,
		"battle_root_child_names": _get_battle_root_child_names(),
		"battle_root_has_scene": battle_root != null and current_battle_scene != null and current_battle_scene.get_parent() == battle_root,
		"battle_root_has_multiple_scenes": battle_root != null and battle_root.get_child_count() > 1,
		"current_scene_path": scene_flow.current_scene_path if scene_flow != null else "",
		"battle_lifecycle_state": battle_session_adapter.get_lifecycle_state() if battle_session_adapter != null and battle_session_adapter.has_method("get_lifecycle_state") else -1,
		"battle_lifecycle_state_name": battle_session_adapter.get_lifecycle_state_name() if battle_session_adapter != null and battle_session_adapter.has_method("get_lifecycle_state_name") else "UNKNOWN",
		"battle_is_active": battle_session_adapter.is_battle_active() if battle_session_adapter != null and battle_session_adapter.has_method("is_battle_active") else false,
		"battle_shutdown_complete": battle_session_adapter.is_shutdown_complete() if battle_session_adapter != null and battle_session_adapter.has_method("is_shutdown_complete") else false,
		"last_runtime_error": last_runtime_error.duplicate(true),
		"diagnostics": diagnostics_dump,
	}


func _on_network_error_routed(payload: Dictionary) -> void:
	last_runtime_error = payload.duplicate(true)
	_last_runtime_error_code = String(last_runtime_error.get("error_code", ""))
	_last_runtime_error_message = String(last_runtime_error.get("user_message", last_runtime_error.get("message", "")))
	if not _last_runtime_error_code.is_empty() or not _last_runtime_error_message.is_empty():
		runtime_error.emit(_last_runtime_error_code, _last_runtime_error_message)


func _on_client_runtime_battle_message_received(message: Dictionary) -> void:
	if battle_session_adapter != null and battle_session_adapter.has_method("ingest_dedicated_server_message"):
		battle_session_adapter.ingest_dedicated_server_message(message)


func _on_client_runtime_transport_connected() -> void:
	if battle_session_adapter != null and battle_session_adapter.has_method("notify_dedicated_server_transport_connected"):
		battle_session_adapter.notify_dedicated_server_transport_connected()


func _on_client_runtime_transport_disconnected() -> void:
	if battle_session_adapter != null and battle_session_adapter.has_method("notify_dedicated_server_transport_disconnected"):
		battle_session_adapter.notify_dedicated_server_transport_disconnected()


func _on_client_runtime_room_error(error_code: String, user_message: String) -> void:
	if battle_session_adapter != null and battle_session_adapter.has_method("notify_dedicated_server_transport_error"):
		battle_session_adapter.notify_dedicated_server_transport_error(error_code, user_message)


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


func _ensure_runtime_config() -> void:
	if runtime_config == null:
		runtime_config = AppRuntimeConfigScript.new()


func _ensure_front_local_state() -> void:
	if auth_session_state == null:
		auth_session_state = AuthSessionStateScript.new()
	if player_profile_state == null:
		player_profile_state = PlayerProfileStateScript.new()
	if front_settings_state == null:
		front_settings_state = FrontSettingsStateScript.new()

	if auth_session_repository != null and auth_session_repository.has_method("load_session"):
		auth_session_state = auth_session_repository.load_session()
		if auth_session_state == null:
			auth_session_state = AuthSessionStateScript.new()
	if profile_repository != null and profile_repository.has_method("load_profile"):
		player_profile_state = profile_repository.load_profile()
		if player_profile_state == null:
			player_profile_state = PlayerProfileStateScript.new()
	if front_settings_repository != null and front_settings_repository.has_method("load_settings"):
		front_settings_state = front_settings_repository.load_settings()
		if front_settings_state == null:
			front_settings_state = FrontSettingsStateScript.new()


func _ensure_front_repositories() -> void:
	if auth_session_repository == null:
		auth_session_repository = LocalAuthSessionRepositoryScript.new()
	elif not (auth_session_repository is AuthSessionRepositoryScript):
		auth_session_repository = LocalAuthSessionRepositoryScript.new()

	if profile_repository == null:
		profile_repository = LocalProfileRepositoryScript.new()
	elif not (profile_repository is ProfileRepositoryScript):
		profile_repository = LocalProfileRepositoryScript.new()

	if front_settings_repository == null:
		front_settings_repository = LocalFrontSettingsRepositoryScript.new()
	elif not (front_settings_repository is FrontSettingsRepositoryScript):
		front_settings_repository = LocalFrontSettingsRepositoryScript.new()


func _ensure_front_services() -> void:
	if auth_gateway == null:
		auth_gateway = HttpAuthGatewayScript.new()
	if runtime_config != null and bool(runtime_config.enable_pass_through_auth_fallback):
		auth_gateway = PassThroughAuthGatewayScript.new()
	if profile_gateway == null:
		profile_gateway = HttpProfileGatewayScript.new()
	if room_ticket_gateway == null:
		room_ticket_gateway = HttpRoomTicketGatewayScript.new()
	if matchmaking_gateway == null:
		matchmaking_gateway = HttpMatchmakingGatewayScript.new()
	if career_gateway == null:
		career_gateway = HttpCareerGatewayScript.new()
	if settlement_gateway == null:
		settlement_gateway = HttpSettlementGatewayScript.new()
	if practice_room_factory == null:
		practice_room_factory = PracticeRoomFactoryScript.new()


func _ensure_front_use_cases() -> void:
	if login_use_case == null:
		login_use_case = LoginUseCaseScript.new()
	if login_use_case != null and login_use_case.has_method("configure"):
		login_use_case.configure(
			auth_gateway,
			auth_session_state,
			auth_session_repository,
			profile_gateway,
			profile_repository,
			front_settings_repository,
			player_profile_state,
			front_settings_state
		)

	if lobby_use_case == null:
		lobby_use_case = LobbyUseCaseScript.new()
	if lobby_use_case != null and lobby_use_case.has_method("configure"):
		lobby_use_case.configure(
			self,
			auth_session_state,
			player_profile_state,
			front_settings_state,
			practice_room_factory,
			auth_session_repository,
			logout_use_case,
			profile_gateway,
			room_ticket_gateway
		)

	if lobby_directory_use_case == null:
		lobby_directory_use_case = LobbyDirectoryUseCaseScript.new()
	if lobby_directory_use_case != null and lobby_directory_use_case.has_method("configure"):
		lobby_directory_use_case.configure(
			client_room_runtime,
			front_settings_state
		)

	if matchmaking_use_case == null:
		matchmaking_use_case = MatchmakingUseCaseScript.new()
	if matchmaking_use_case != null and matchmaking_use_case.has_method("configure"):
		matchmaking_use_case.configure(
			auth_session_state,
			player_profile_state,
			front_settings_state,
			matchmaking_gateway,
			room_ticket_gateway
		)

	if career_use_case == null:
		career_use_case = CareerUseCaseScript.new()
	if career_use_case != null and career_use_case.has_method("configure"):
		career_use_case.configure(
			auth_session_state,
			front_settings_state,
			career_gateway
		)

	if room_use_case == null:
		room_use_case = RoomUseCaseScript.new()
	if room_use_case != null and room_use_case.has_method("configure"):
		room_use_case.configure(self)

	if current_room_entry_context == null:
		current_room_entry_context = RoomEntryContextScript.new()

	if loading_use_case == null:
		loading_use_case = LoadingUseCaseScript.new()
	if loading_use_case != null and loading_use_case.has_method("configure"):
		var gateway = null
		if room_use_case != null:
			gateway = room_use_case.get("room_client_gateway")
		loading_use_case.configure(self, gateway)

	if settlement_sync_use_case == null:
		settlement_sync_use_case = SettlementSyncUseCaseScript.new()
	if settlement_sync_use_case != null and settlement_sync_use_case.has_method("configure"):
		settlement_sync_use_case.configure(
			auth_session_state,
			front_settings_state,
			settlement_gateway
		)

	if auth_session_restore_use_case == null:
		var restore_script = _try_load_script("res://app/front/auth/auth_session_restore_use_case.gd")
		if restore_script != null:
			auth_session_restore_use_case = restore_script.new()
	if auth_session_restore_use_case != null and auth_session_restore_use_case.has_method("configure"):
		auth_session_restore_use_case.configure(self)

	if register_use_case == null:
		var register_script = _try_load_script("res://app/front/auth/register_use_case.gd")
		if register_script != null:
			register_use_case = register_script.new()
	if register_use_case != null and register_use_case.has_method("configure"):
		register_use_case.configure(self)

	if refresh_session_use_case == null:
		var refresh_script = _try_load_script("res://app/front/auth/refresh_session_use_case.gd")
		if refresh_script != null:
			refresh_session_use_case = refresh_script.new()
	if refresh_session_use_case != null and refresh_session_use_case.has_method("configure"):
		refresh_session_use_case.configure(self)

	if logout_use_case == null:
		var logout_script = _try_load_script("res://app/front/auth/logout_use_case.gd")
		if logout_script != null:
			logout_use_case = logout_script.new()
	if logout_use_case != null and logout_use_case.has_method("configure"):
		logout_use_case.configure(self)


func _get_battle_root_child_names() -> Array:
	if battle_root == null:
		return []
	var names: Array = []
	for child in battle_root.get_children():
		names.append(child.name)
	return names


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
		return
	current_battle_content_manifest = _content_manifest_builder.build_for_start_config(current_start_config)


func _exit_tree() -> void:
	_clear_pending_runtime_meta()
	_initialization_in_progress = false
	_set_runtime_state(RuntimeLifecycleStateScript.Value.DISPOSING, "_exit_tree")
	runtime_disposing.emit()
	if room_use_case != null and room_use_case.has_method("dispose"):
		room_use_case.dispose()
	_set_runtime_state(RuntimeLifecycleStateScript.Value.DISPOSED, "_exit_tree")
	runtime_disposed.emit()


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
