extends Node

const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const RuntimeMessageRouterScript = preload("res://network/session/runtime/runtime_message_router.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const LocalLoopbackTransportScript = preload("res://network/transport/local_loopback_transport.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")

const NETWORK_MODE_LOCAL_LOOPBACK := 0
const NETWORK_MODE_HOST := 1
const NETWORK_MODE_CLIENT := 2

signal log_event(message)
signal host_match_started(config)
signal client_config_accepted(config)
signal client_prediction_event(event)
signal network_battle_finished(result, is_host)
signal client_battle_finished(result)

var authority_runtime: AuthorityRuntime = null
var client_runtime: ClientRuntime = null
var match_start_coordinator = null
var runtime_message_router: RuntimeMessageRouter = null


static func create_transport(network_mode: int) -> Node:
	match network_mode:
		NETWORK_MODE_HOST, NETWORK_MODE_CLIENT:
			return ENetBattleTransportScript.new()
		_:
			return LocalLoopbackTransportScript.new()


static func build_transport_config(
	network_mode: int,
	start_config: BattleStartConfig,
	local_peer_id: int,
	host: String,
	port: int,
	max_clients: int,
	debug_profile: Dictionary = {}
) -> Dictionary:
	var config := {
		"is_server": network_mode != NETWORK_MODE_CLIENT,
		"local_peer_id": local_peer_id,
		"remote_peer_ids": resolve_remote_peer_ids(start_config, local_peer_id),
		"seed": int(start_config.battle_seed) ^ 0x51A7 if start_config != null else 0,
		"debug_profile": debug_profile,
		"host": host,
		"port": port,
		"max_clients": max_clients,
	}
	if network_mode == NETWORK_MODE_CLIENT:
		config["local_peer_id"] = 0
		config["remote_peer_ids"] = []
	return config


static func resolve_remote_peer_ids(config: BattleStartConfig, local_peer_id: int) -> Array[int]:
	var remote_peer_ids: Array[int] = []
	if config == null:
		return remote_peer_ids
	for player_entry in config.players:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id < 0 or peer_id == local_peer_id:
			continue
		remote_peer_ids.append(peer_id)
	return remote_peer_ids


func ensure_match_start_coordinator() -> Node:
	if match_start_coordinator == null:
		match_start_coordinator = MatchStartCoordinatorScript.new()
		add_child(match_start_coordinator)
	return match_start_coordinator


func ensure_runtime_message_router(handlers: Dictionary, fallback_handler: Callable) -> RuntimeMessageRouter:
	if runtime_message_router != null:
		return runtime_message_router
	runtime_message_router = RuntimeMessageRouterScript.new()
	add_child(runtime_message_router)
	for message_type in handlers.keys():
		var handler: Callable = handlers[message_type]
		runtime_message_router.register_handler(String(message_type), handler)
	if fallback_handler.is_valid():
		runtime_message_router.set_fallback_handler(fallback_handler)
	return runtime_message_router


func ensure_authority_runtime() -> AuthorityRuntime:
	if authority_runtime != null:
		return authority_runtime
	authority_runtime = AuthorityRuntimeScript.new()
	add_child(authority_runtime)
	authority_runtime.log_event.connect(func(message: String) -> void:
		log_event.emit(message)
	)
	authority_runtime.match_started.connect(func(config: BattleStartConfig) -> void:
		host_match_started.emit(config)
	)
	authority_runtime.battle_finished.connect(func(result: BattleResult) -> void:
		network_battle_finished.emit(result, true)
	)
	return authority_runtime


func ensure_client_runtime() -> ClientRuntime:
	if client_runtime != null:
		return client_runtime
	client_runtime = ClientRuntimeScript.new()
	add_child(client_runtime)
	client_runtime.log_event.connect(func(message: String) -> void:
		log_event.emit(message)
	)
	client_runtime.config_accepted.connect(func(config: BattleStartConfig) -> void:
		client_config_accepted.emit(config)
	)
	client_runtime.prediction_event.connect(func(event: Dictionary) -> void:
		client_prediction_event.emit(event)
	)
	client_runtime.battle_finished.connect(func(result: BattleResult) -> void:
		client_battle_finished.emit(result)
		network_battle_finished.emit(result, false)
	)
	return client_runtime


func shutdown() -> void:
	if authority_runtime != null:
		authority_runtime.shutdown_runtime()
		_free_node(authority_runtime)
		authority_runtime = null
	if client_runtime != null:
		client_runtime.shutdown_runtime()
		_free_node(client_runtime)
		client_runtime = null
	if match_start_coordinator != null:
		_free_node(match_start_coordinator)
		match_start_coordinator = null
	if runtime_message_router != null:
		_free_node(runtime_message_router)
		runtime_message_router = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if is_instance_valid(node):
		node.queue_free()
