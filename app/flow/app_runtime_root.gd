extends Node

const ROOT_NODE_NAME: String = "AppRoot"
const LEGACY_ROOT_NODE_NAME: String = "AppRuntimeRoot"
const ROOM_SCENE_PATH := "res://scenes/front/room_scene.tscn"
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const DebugToolsScript = preload("res://app/flow/phase3_debug_tools.gd")

var local_peer_id: int = 1
var remote_peer_id: int = 2

var front_flow: Node = null
var scene_flow: Node = null
var session_root: Node = null
var battle_root: Node = null
var debug_tools: Node = null
var room_session_controller: Node = null
var match_start_coordinator: Node = null
var battle_session_adapter: Node = null

var current_room_snapshot: RoomSnapshot = null
var current_start_config: BattleStartConfig = null
var current_battle_scene: Node = null
var current_battle_bootstrap: BattleBootstrap = null
var current_presentation_bridge: BattlePresentationBridge = null
var current_battle_hud_controller: BattleHudController = null
var current_battle_camera_controller: BattleCameraController = null
var current_settlement_controller: SettlementController = null


static func ensure_in_tree(tree: SceneTree):
	if tree == null:
		return null
	if tree.root.has_node(ROOT_NODE_NAME):
		return tree.root.get_node(ROOT_NODE_NAME)
	if tree.root.has_node(LEGACY_ROOT_NODE_NAME):
		var legacy_root := tree.root.get_node(LEGACY_ROOT_NODE_NAME)
		if legacy_root != null:
			legacy_root.name = ROOT_NODE_NAME
			legacy_root.initialize_runtime()
			return legacy_root
	var runtime = load("res://app/flow/app_runtime_root.gd").new()
	runtime.name = ROOT_NODE_NAME
	tree.root.add_child(runtime)
	runtime.initialize_runtime()
	return runtime


func _ready() -> void:
	initialize_runtime()


func initialize_runtime() -> void:
	name = ROOT_NODE_NAME
	_ensure_root_nodes()

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

	if scene_flow.current_scene_path.is_empty():
		scene_flow.current_scene_path = ROOM_SCENE_PATH
	if int(front_flow.current_state) == int(FrontFlowControllerScript.FlowState.BOOT):
		front_flow.current_state = FrontFlowControllerScript.FlowState.ROOM


func build_and_store_start_config(snapshot: RoomSnapshot) -> BattleStartConfig:
	if snapshot == null or match_start_coordinator == null:
		return null
	current_room_snapshot = snapshot.duplicate_deep()
	current_start_config = match_start_coordinator.build_start_config(snapshot)
	if battle_session_adapter != null and current_start_config != null:
		battle_session_adapter.setup_from_start_config(current_start_config)
	return current_start_config


func clear_battle_payload() -> void:
	current_start_config = null


func register_battle_modules(
	battle_scene: Node,
	bootstrap: BattleBootstrap,
	bridge: BattlePresentationBridge,
	hud: BattleHudController,
	camera_controller: BattleCameraController,
	settlement_controller: SettlementController
) -> void:
	current_battle_scene = battle_scene
	current_battle_bootstrap = bootstrap
	current_presentation_bridge = bridge
	current_battle_hud_controller = hud
	current_battle_camera_controller = camera_controller
	current_settlement_controller = settlement_controller
	if battle_scene != null and battle_root != null and battle_scene.get_parent() != battle_root:
		_reparent_to(battle_scene, battle_root)


func unregister_battle_modules(battle_scene: Node) -> void:
	if battle_scene != null and current_battle_scene != battle_scene:
		return
	current_battle_scene = null
	current_battle_bootstrap = null
	current_presentation_bridge = null
	current_battle_hud_controller = null
	current_battle_camera_controller = null
	current_settlement_controller = null


func debug_dump_runtime_structure() -> Dictionary:
	return {
		"root_name": name,
		"has_session_root": session_root != null,
		"has_battle_root": battle_root != null,
		"has_debug_tools": debug_tools != null,
		"has_active_battle_scene": current_battle_scene != null,
		"has_active_battle_bootstrap": current_battle_bootstrap != null,
		"has_active_presentation_bridge": current_presentation_bridge != null,
		"has_active_battle_hud": current_battle_hud_controller != null,
		"has_active_battle_camera": current_battle_camera_controller != null,
		"has_active_settlement": current_settlement_controller != null,
		"battle_root_children": battle_root.get_child_count() if battle_root != null else 0,
		"battle_root_has_scene": battle_root != null and current_battle_scene != null and current_battle_scene.get_parent() == battle_root,
	}


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
