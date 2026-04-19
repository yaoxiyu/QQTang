extends RefCounted

const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")


static func ensure_components(runtime: Node) -> void:
	if runtime == null:
		return
	_ensure_room_session_controller(runtime)
	_ensure_match_start_coordinator(runtime)
	_ensure_battle_session_adapter(runtime)
	_ensure_client_room_runtime(runtime)
	_connect_runtime_signals(runtime)


static func _ensure_room_session_controller(runtime: Node) -> void:
	if runtime.room_session_controller == null or not is_instance_valid(runtime.room_session_controller):
		runtime.room_session_controller = RoomSessionControllerScript.new()
		runtime.room_session_controller.name = "RoomSessionController"
		runtime.session_root.add_child(runtime.room_session_controller)
	elif runtime.room_session_controller.get_parent() != runtime.session_root:
		runtime._reparent_to(runtime.room_session_controller, runtime.session_root)
	if runtime.room_session_controller != null and runtime.room_session_controller.has_method("set_local_player_id"):
		runtime.room_session_controller.set_local_player_id(runtime.local_peer_id)
	if runtime.practice_room_factory != null and runtime.practice_room_factory.has_method("configure"):
		runtime.practice_room_factory.configure(runtime.room_session_controller)


static func _ensure_match_start_coordinator(runtime: Node) -> void:
	if runtime.match_start_coordinator == null or not is_instance_valid(runtime.match_start_coordinator):
		runtime.match_start_coordinator = MatchStartCoordinatorScript.new()
		runtime.match_start_coordinator.name = "MatchStartCoordinator"
		runtime.session_root.add_child(runtime.match_start_coordinator)
	elif runtime.match_start_coordinator.get_parent() != runtime.session_root:
		runtime._reparent_to(runtime.match_start_coordinator, runtime.session_root)


static func _ensure_battle_session_adapter(runtime: Node) -> void:
	if runtime.battle_session_adapter == null or not is_instance_valid(runtime.battle_session_adapter):
		runtime.battle_session_adapter = BattleSessionAdapterScript.new()
		runtime.battle_session_adapter.name = "BattleSessionAdapter"
		runtime.session_root.add_child(runtime.battle_session_adapter)
	elif runtime.battle_session_adapter.get_parent() != runtime.session_root:
		runtime._reparent_to(runtime.battle_session_adapter, runtime.session_root)


static func _ensure_client_room_runtime(runtime: Node) -> void:
	if runtime.client_room_runtime == null or not is_instance_valid(runtime.client_room_runtime):
		runtime.client_room_runtime = ClientRoomRuntimeScript.new()
		runtime.client_room_runtime.name = "ClientRoomRuntime"
		runtime.session_root.add_child(runtime.client_room_runtime)
	elif runtime.client_room_runtime.get_parent() != runtime.session_root:
		runtime._reparent_to(runtime.client_room_runtime, runtime.session_root)


static func _connect_runtime_signals(runtime: Node) -> void:
	if runtime.client_room_runtime == null or runtime.battle_session_adapter == null:
		return
	if not runtime.client_room_runtime.battle_message_received.is_connected(runtime._on_client_runtime_battle_message_received):
		runtime.client_room_runtime.battle_message_received.connect(runtime._on_client_runtime_battle_message_received)
	if not runtime.client_room_runtime.transport_connected.is_connected(runtime._on_client_runtime_transport_connected):
		runtime.client_room_runtime.transport_connected.connect(runtime._on_client_runtime_transport_connected)
	if not runtime.client_room_runtime.transport_disconnected.is_connected(runtime._on_client_runtime_transport_disconnected):
		runtime.client_room_runtime.transport_disconnected.connect(runtime._on_client_runtime_transport_disconnected)
	if not runtime.client_room_runtime.room_error.is_connected(runtime._on_client_runtime_room_error):
		runtime.client_room_runtime.room_error.connect(runtime._on_client_runtime_room_error)
