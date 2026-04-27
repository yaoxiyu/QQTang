extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RemoteDebugInputDriverScript = preload("res://network/session/runtime/remote_debug_input_driver.gd")
const PredictionDivergenceDebuggerScript = preload("res://network/session/runtime/prediction_divergence_debugger.gd")
const BattleSessionBootstrapScript = preload("res://network/session/battle_session_bootstrap.gd")
const ClientRuntimeMetricsCollectorScript = preload("res://network/session/runtime/client_runtime_metrics_collector.gd")
const NETWORK_GATEWAY_PATH := "res://network/session/battle_session_network_gateway.gd"
const DEFAULT_MATCH_DURATION_TICKS: int = BattleStartConfig.DEFAULT_MATCH_DURATION_TICKS

signal adapter_configured()
signal battle_session_started(config)
signal battle_context_created(context)
signal authoritative_tick_completed(context, tick_result, metrics)
signal battle_finished_authoritatively(result)
signal battle_session_stopped()
signal prediction_debug_event(event)
signal network_log_event(message)
signal network_host_match_started(config)
signal network_client_match_started(config)
signal network_battle_finished(result, is_host)
signal network_transport_connected()
signal network_transport_disconnected()
signal network_transport_peer_connected(peer_id)
signal network_transport_peer_disconnected(peer_id)
signal network_transport_error(code, message)

enum BattleLifecycleState {
	IDLE,
	STARTING,
	RUNNING,
	FINISHING,
	SHUTTING_DOWN,
	STOPPED,
}

enum BattleNetworkMode {
	LOCAL_LOOPBACK,
	HOST,
	CLIENT,
}

var start_config: BattleStartConfig = null
var client_session: ClientSession = null
var server_session: ServerSession = null
var prediction_controller: PredictionController = null
var visual_sync_controller: VisualSyncController = null
var current_context: BattleContext = null
var transport: IBattleTransport = null
var network_mode: int = BattleNetworkMode.LOCAL_LOOPBACK
var network_host: String = "127.0.0.1"
var network_port: int = 9000
var network_max_clients: int = 8
var _remote_debug_input_driver: RemoteDebugInputDriver = RemoteDebugInputDriverScript.new()
var _prediction_debugger: PredictionDivergenceDebugger = PredictionDivergenceDebuggerScript.new()
var _metrics_collector: RefCounted = ClientRuntimeMetricsCollectorScript.new()
var use_remote_debug_inputs: bool = false
var _local_peer_id: int = 0
var _finished_emitted: bool = false
var _correction_count: int = 0
var _last_correction_summary: String = ""
var _last_resync_tick: int = -1
var _lifecycle_state: int = BattleLifecycleState.STOPPED
var _bootstrap_authority_runtime: AuthorityRuntime = null
var _bootstrap_client_runtime: ClientRuntime = null
var _bootstrap_coordinator = null
var _bootstrap_local_peer_id: int = 0
var _runtime_message_router: RuntimeMessageRouter = null
var _battle_session_bootstrap: Node = null
var _network_gateway = null

# LegacyMigration: Resume snapshot storage
var pending_resume_snapshot = null


func _ready() -> void:
	_ensure_network_gateway()


func setup_from_start_config(config: BattleStartConfig) -> void:
	_ensure_network_gateway()
	start_config = config.duplicate_deep() if config != null else null
	_lifecycle_state = BattleLifecycleState.IDLE if start_config != null else BattleLifecycleState.STOPPED


# LegacyMigration: Apply resume snapshot for battle recovery
func apply_resume_snapshot(snapshot) -> void:
	_ensure_network_gateway()
	pending_resume_snapshot = snapshot
	if pending_resume_snapshot == null:
		return
	if _bootstrap_client_runtime == null:
		return
	if not _bootstrap_client_runtime.is_active():
		return
	if pending_resume_snapshot.checkpoint_message.is_empty():
		pending_resume_snapshot = null
		return
	_bootstrap_client_runtime.inject_resume_checkpoint_message(pending_resume_snapshot.checkpoint_message)
	pending_resume_snapshot = null


func start_battle() -> void:
	_ensure_network_gateway()
	if start_config == null:
		return
	var pending_config := start_config.duplicate_deep()
	if is_battle_active():
		shutdown_battle()
	start_config = pending_config.duplicate_deep() if pending_config != null else null
	var config := pending_config.duplicate_deep() if pending_config != null else null
	var mode := _resolve_runtime_mode(config)
	if mode < 0:
		push_error("BattleSessionAdapter.start_battle rejected session_mode=%s topology=%s" % [String(config.session_mode), String(config.topology)])
		_lifecycle_state = BattleLifecycleState.STOPPED
		return
	_lifecycle_state = BattleLifecycleState.STARTING
	var options: Dictionary = {}
	if mode == BattleNetworkMode.LOCAL_LOOPBACK:
		options["debug_profile"] = _capture_transport_profile()
	if not _start_runtime_session(mode, config, options):
		_lifecycle_state = BattleLifecycleState.STOPPED
		return
	_lifecycle_state = BattleLifecycleState.RUNNING
	battle_session_started.emit(config)
	battle_context_created.emit(current_context)


func advance_authoritative_tick(local_input: Dictionary = {}) -> void:
	if current_context == null or _finished_emitted:
		return
	match network_mode:
		BattleNetworkMode.LOCAL_LOOPBACK:
			if server_session == null or server_session.active_match == null:
				return
			_advance_local_loopback_runtime_tick(local_input)
		BattleNetworkMode.CLIENT:
			_advance_client_runtime_tick(local_input)
		_:
			return


func _advance_local_loopback_runtime_tick(local_input: Dictionary = {}) -> void:
	var next_tick: int = server_session.active_match.sim_world.state.match_state.tick + 1
	var input_message := _bootstrap_client_runtime.build_local_input_message(local_input) if _bootstrap_client_runtime != null else {}
	if not input_message.is_empty() and transport != null:
		transport.send_to_peer(_local_peer_id, input_message)
	_enqueue_remote_inputs(next_tick)
	_poll_transport(next_tick)
	network_bootstrap_route_messages(transport.consume_incoming() if transport != null else [])
	_flush_client_inputs_to_server()
	var outgoing_messages := _bootstrap_authority_runtime.advance_authoritative_tick({}) if _bootstrap_authority_runtime != null else []
	if transport != null:
		_set_transport_tick(next_tick)
		for message in outgoing_messages:
			transport.broadcast(message)
	_poll_transport(next_tick)
	network_bootstrap_route_messages(transport.consume_incoming() if transport != null else [])

	var world: SimWorld = current_context.sim_world
	if world == null:
		return

	var tick_result := {
		"tick": world.state.match_state.tick,
		"events": world.events.get_events(),
		"phase": world.state.match_state.phase,
	}
	var metrics: Dictionary = _build_runtime_metrics()
	authoritative_tick_completed.emit(current_context, tick_result, metrics)

	if int(world.state.match_state.phase) == MatchState.Phase.ENDED:
		_finished_emitted = true
		_lifecycle_state = BattleLifecycleState.FINISHING
		battle_finished_authoritatively.emit(
			BattleResult.from_authoritative_state(world, current_context.battle_start_config, _local_peer_id)
		)


func shutdown_battle() -> void:
	_ensure_network_gateway()
	if _lifecycle_state != BattleLifecycleState.STOPPED:
		_lifecycle_state = BattleLifecycleState.SHUTTING_DOWN

	var runtime_owned: bool = _current_runtime_owned_by_runtime_modules()

	if prediction_controller != null:
		if prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
			prediction_controller.prediction_corrected.disconnect(_on_prediction_corrected)
		if prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
			prediction_controller.full_visual_resync.disconnect(_on_full_visual_resync)

	if current_context != null and not runtime_owned:
		current_context.clear_runtime_refs()

	_remote_debug_input_driver.shutdown()

	if runtime_owned:
		if _bootstrap_client_runtime != null:
			_bootstrap_client_runtime.shutdown_runtime()
		if _bootstrap_authority_runtime != null:
			_bootstrap_authority_runtime.shutdown_runtime()
	elif prediction_controller != null:
		prediction_controller.dispose()
		if is_instance_valid(prediction_controller):
			prediction_controller.free()
	prediction_controller = null

	if visual_sync_controller != null and is_instance_valid(visual_sync_controller):
		visual_sync_controller.free()
	visual_sync_controller = null

	if not runtime_owned and client_session != null and is_instance_valid(client_session):
		client_session.free()
	client_session = null

	if not runtime_owned and server_session != null and is_instance_valid(server_session):
		server_session.free()
	server_session = null

	_network_gateway.shutdown_transport()

	current_context = null
	start_config = null
	_local_peer_id = 0
	_finished_emitted = false
	_prediction_debugger.clear()
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1
	_lifecycle_state = BattleLifecycleState.STOPPED
	battle_session_stopped.emit()


func get_lifecycle_state() -> int:
	return _lifecycle_state


func get_lifecycle_state_name() -> String:
	match _lifecycle_state:
		BattleLifecycleState.IDLE:
			return "IDLE"
		BattleLifecycleState.STARTING:
			return "STARTING"
		BattleLifecycleState.RUNNING:
			return "RUNNING"
		BattleLifecycleState.FINISHING:
			return "FINISHING"
		BattleLifecycleState.SHUTTING_DOWN:
			return "SHUTTING_DOWN"
		BattleLifecycleState.STOPPED:
			return "STOPPED"
		_:
			return "UNKNOWN"


func is_battle_active() -> bool:
	return _lifecycle_state == BattleLifecycleState.STARTING or _lifecycle_state == BattleLifecycleState.RUNNING or _lifecycle_state == BattleLifecycleState.FINISHING or _lifecycle_state == BattleLifecycleState.SHUTTING_DOWN


func is_shutdown_complete() -> bool:
	return _lifecycle_state == BattleLifecycleState.STOPPED


func cycle_latency_profile() -> int:
	_ensure_transport_for_debug()
	return _metrics_collector.cycle_latency_profile(transport)


func cycle_loss_profile() -> int:
	_ensure_transport_for_debug()
	return _metrics_collector.cycle_loss_profile(transport)


func toggle_remote_debug_inputs() -> bool:
	use_remote_debug_inputs = not use_remote_debug_inputs
	return use_remote_debug_inputs


func arm_force_prediction_divergence() -> void:
	prediction_debug_event.emit(_prediction_debugger.arm())


func get_latency_profile_ms() -> int:
	_ensure_transport_for_debug()
	return _metrics_collector.get_latency_profile_ms(transport)


func get_packet_loss_percent() -> int:
	_ensure_transport_for_debug()
	return _metrics_collector.get_packet_loss_percent(transport)


func get_network_profile_summary() -> String:
	_ensure_transport_for_debug()
	return _metrics_collector.get_network_profile_summary(transport)


func build_runtime_metrics_snapshot() -> Dictionary:
	return _build_runtime_metrics()


func _start_runtime_session(mode: int, config: BattleStartConfig, options: Dictionary = {}) -> bool:
	if not _validate_runtime_start_config(config):
		return false
	match mode:
		BattleNetworkMode.LOCAL_LOOPBACK:
			return _start_local_loopback_runtime(config, options)
		BattleNetworkMode.HOST:
			return _start_host_runtime(config, options)
		BattleNetworkMode.CLIENT:
			return _start_client_runtime(config, options)
		_:
			return false


func _start_local_loopback_runtime(config: BattleStartConfig, options: Dictionary = {}) -> bool:
	var pending_config: BattleStartConfig = config.duplicate_deep() if config != null else null
	var profile: Dictionary = options.get("debug_profile", {})
	shutdown_battle()
	start_config = pending_config.duplicate_deep() if pending_config != null else null
	if start_config == null:
		return false
	network_mode = BattleNetworkMode.LOCAL_LOOPBACK

	_local_peer_id = _resolve_local_peer_id(start_config)
	_finished_emitted = false
	_prediction_debugger.clear()
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1

	_ensure_bootstrap_authority_runtime()
	_ensure_bootstrap_client_runtime()
	_bootstrap_authority_runtime.configure(_local_peer_id)
	_bootstrap_client_runtime.configure(_local_peer_id)

	_remote_debug_input_driver.setup(self, start_config, _local_peer_id)

	_network_gateway.initialize_transport(profile)

	var authority_started: bool = _bootstrap_authority_runtime.start_match(start_config)
	var client_started: bool = _bootstrap_client_runtime.start_match(start_config)
	server_session = _bootstrap_authority_runtime.server_session
	client_session = _bootstrap_client_runtime.client_session
	prediction_controller = _bootstrap_client_runtime.prediction_controller
	if not authority_started or not client_started or server_session == null or server_session.active_match == null or client_session == null or prediction_controller == null:
		_lifecycle_state = BattleLifecycleState.STOPPED
		return false
	visual_sync_controller = VisualSyncController.new()
	add_child(visual_sync_controller)
	if not prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
		prediction_controller.prediction_corrected.connect(_on_prediction_corrected)
	if not prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
		prediction_controller.full_visual_resync.connect(_on_full_visual_resync)

	var initial_snapshot: WorldSnapshot = server_session.active_match.snapshot_service.build_standard_snapshot(
		server_session.active_match.sim_world,
		server_session.active_match.sim_world.state.match_state.tick
	)
	prediction_controller.on_authoritative_snapshot(initial_snapshot)

	current_context = BattleContext.new()
	current_context.battle_start_config = start_config.duplicate_deep()
	current_context.sim_world = server_session.active_match.sim_world
	current_context.tick_runner = server_session.active_match.sim_world.tick_runner
	current_context.client_session = client_session
	current_context.server_session = server_session
	current_context.prediction_controller = prediction_controller
	current_context.rollback_controller = prediction_controller.rollback_controller
	current_context.visual_sync_controller = visual_sync_controller

	adapter_configured.emit()
	return true


func _start_host_runtime(config: BattleStartConfig, options: Dictionary = {}) -> bool:
	_ensure_bootstrap_authority_runtime()
	start_config = config.duplicate_deep() if config != null else null
	_bootstrap_local_peer_id = int(options.get("local_peer_id", _bootstrap_local_peer_id))
	_bootstrap_authority_runtime.configure(_bootstrap_local_peer_id if _bootstrap_local_peer_id > 0 else 1)
	return _bootstrap_authority_runtime.start_match(start_config)


func _start_client_runtime(config: BattleStartConfig, options: Dictionary = {}) -> bool:
	return _network_gateway.start_client_runtime(config, options)


func _advance_client_runtime_tick(local_input: Dictionary = {}) -> void:
	_network_gateway.advance_client_runtime_tick(local_input)


func _enqueue_remote_inputs(tick_id: int) -> void:
	_remote_debug_input_driver.enqueue_inputs(tick_id, use_remote_debug_inputs)


func _flush_client_inputs_to_server() -> void:
	if server_session == null:
		return
	if client_session != null:
		for frame in client_session.flush_outgoing_inputs():
			server_session.receive_input(frame)
	_remote_debug_input_driver.flush_to_server(server_session)


func _poll_transport(current_tick: int) -> void:
	if transport == null:
		return
	_set_transport_tick(current_tick)
	transport.poll()


func _build_runtime_metrics() -> Dictionary:
	var metrics: Dictionary = _metrics_collector.build_runtime_metrics(
		_lifecycle_state,
		get_lifecycle_state_name(),
		is_battle_active(),
		is_shutdown_complete(),
		current_context,
		client_session,
		prediction_controller,
		transport,
		_prediction_debugger,
		_correction_count,
		_last_correction_summary,
		_last_resync_tick,
		use_remote_debug_inputs
	)
	if _bootstrap_client_runtime != null and _bootstrap_client_runtime.has_method("get_last_authority_batch_metrics"):
		metrics["authority_batch"] = _bootstrap_client_runtime.get_last_authority_batch_metrics()
	if _bootstrap_client_runtime != null and _bootstrap_client_runtime.has_method("build_metrics"):
		var client_metrics: Dictionary = _bootstrap_client_runtime.build_metrics()
		metrics["rollback"] = client_metrics.get("rollback", {})
	return metrics


func ingest_dedicated_server_message(message: Dictionary) -> void:
	_network_gateway.ingest_dedicated_server_message(message)


func poll_dedicated_client_transport() -> void:
	_network_gateway.poll_dedicated_client_transport()


func is_dedicated_authority_ready() -> bool:
	return _network_gateway.is_dedicated_authority_ready()


func _resolve_runtime_mode(config: BattleStartConfig) -> int:
	if config == null:
		return BattleNetworkMode.LOCAL_LOOPBACK
	if String(config.session_mode) == "network_client" and String(config.topology) == "dedicated_server":
		return BattleNetworkMode.CLIENT
	if String(config.session_mode) == "online_room" and String(config.topology) == "dedicated_server":
		if int(config.local_peer_id) > 0 and int(config.controlled_peer_id) > 0:
			return BattleNetworkMode.CLIENT
		return -1
	if String(config.session_mode) == "network_dedicated_server":
		return -1
	if String(config.session_mode) == "singleplayer_local" and (String(config.topology) == "listen" or String(config.topology) == "local"):
		return BattleNetworkMode.LOCAL_LOOPBACK
	return BattleNetworkMode.LOCAL_LOOPBACK


func _resolve_local_peer_id(config: BattleStartConfig) -> int:
	if config == null:
		return 1
	if int(config.local_peer_id) > 0:
		return int(config.local_peer_id)
	if config.players.is_empty():
		return 1
	return int(config.players[0].get("peer_id", 1))


func _validate_runtime_start_config(config: BattleStartConfig) -> bool:
	if config == null:
		push_error("Failed to start battle: missing BattleStartConfig")
		return false
	return true


func _current_runtime_owned_by_runtime_modules() -> bool:
	if _bootstrap_authority_runtime != null and server_session != null and server_session == _bootstrap_authority_runtime.server_session:
		return true
	if _bootstrap_client_runtime != null:
		if client_session != null and client_session == _bootstrap_client_runtime.client_session:
			return true
		if prediction_controller != null and prediction_controller == _bootstrap_client_runtime.prediction_controller:
			return true
	return false


func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	_correction_count += 1
	_last_correction_summary = "E%d(fp) %s -> %s" % [entity_id, str(from_pos), str(to_pos)]
	prediction_debug_event.emit({
		"type": "prediction_corrected",
		"entity_id": entity_id,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"message": "Rollback corrected(fp) E%d %s -> %s" % [entity_id, str(from_pos), str(to_pos)],
	})


func _on_full_visual_resync(snapshot: WorldSnapshot) -> void:
	_last_resync_tick = snapshot.tick_id if snapshot != null else -1
	prediction_debug_event.emit({
		"type": "full_resync",
		"tick": _last_resync_tick,
		"message": "Full resync at tick %d" % _last_resync_tick,
	})


func _ensure_transport_for_debug() -> void:
	_ensure_network_gateway()
	if transport != null:
		return
	_network_gateway.initialize_transport({})


func _ensure_network_gateway() -> void:
	if _network_gateway == null:
		var gateway_script = load(NETWORK_GATEWAY_PATH)
		if gateway_script != null and gateway_script.has_method("new"):
			_network_gateway = gateway_script.new()
	if _network_gateway != null:
		_network_gateway.configure(self)


func _capture_transport_profile() -> Dictionary:
	return _metrics_collector.capture_transport_profile(transport)


func _set_transport_tick(tick_id: int) -> void:
	if transport != null and transport.has_method("set_current_tick"):
		transport.call("set_current_tick", tick_id)


func network_bootstrap_configure_host(local_peer_id: int = 1) -> void:
	_network_gateway.configure_host(local_peer_id)


func network_bootstrap_configure_client(local_peer_id: int = 0) -> void:
	_network_gateway.configure_client(local_peer_id)


func network_bootstrap_set_local_peer_id(local_peer_id: int) -> void:
	_network_gateway.set_local_peer_id(local_peer_id)


func notify_dedicated_server_transport_connected() -> void:
	_network_gateway.notify_dedicated_server_transport_connected()


func notify_dedicated_server_transport_disconnected() -> void:
	_network_gateway.notify_dedicated_server_transport_disconnected()


func notify_dedicated_server_transport_error(error_code: String, user_message: String) -> void:
	_network_gateway.notify_dedicated_server_transport_error(error_code, user_message)


func network_bootstrap_start_host_match(config: BattleStartConfig) -> bool:
	return _network_gateway.start_host_match(config)


func network_bootstrap_build_start_config(snapshot: RoomSnapshot) -> BattleStartConfig:
	return _network_gateway.build_start_config(snapshot)


func network_bootstrap_route_messages(messages: Array[Dictionary]) -> void:
	_network_gateway.route_messages(messages)


func network_bootstrap_build_host_tick_messages(local_input: Dictionary = {}) -> Array[Dictionary]:
	return _network_gateway.build_host_tick_messages(local_input)


func network_bootstrap_build_client_input_message(local_input: Dictionary = {}) -> Dictionary:
	return _network_gateway.build_client_input_message(local_input)


func network_bootstrap_is_host_match_running() -> bool:
	return _network_gateway.is_host_match_running()


func network_bootstrap_is_client_active() -> bool:
	return _network_gateway.is_client_active()


func network_bootstrap_build_client_metrics() -> Dictionary:
	return _network_gateway.build_client_metrics()


func network_bootstrap_shutdown() -> void:
	_network_gateway.shutdown_bootstrap()


func network_bootstrap_start_host_transport(port: int, max_clients: int) -> void:
	_network_gateway.start_host_transport(port, max_clients)


func network_bootstrap_start_client_transport(host: String, port: int, connect_timeout_seconds: float = 5.0) -> void:
	_network_gateway.start_client_transport(host, port, connect_timeout_seconds)


func network_bootstrap_poll_transport() -> void:
	_network_gateway.poll_transport()


func network_bootstrap_transport_connected() -> bool:
	return _network_gateway.transport_connected()


func network_bootstrap_transport_remote_peer_ids() -> Array[int]:
	return _network_gateway.transport_remote_peer_ids()


func network_bootstrap_transport_local_peer_id() -> int:
	return _network_gateway.transport_local_peer_id()


func network_bootstrap_send_to_peer(peer_id: int, message: Dictionary) -> void:
	_network_gateway.send_to_peer(peer_id, message)


func network_bootstrap_broadcast(message: Dictionary) -> void:
	_network_gateway.broadcast(message)


func _ensure_bootstrap_coordinator() -> void:
	_ensure_battle_session_bootstrap()
	_bootstrap_coordinator = _battle_session_bootstrap.ensure_match_start_coordinator()


func _ensure_runtime_message_router() -> void:
	_ensure_battle_session_bootstrap()
	_runtime_message_router = _battle_session_bootstrap.ensure_runtime_message_router({
		TransportMessageTypesScript.JOIN_BATTLE_REQUEST: Callable(_network_gateway, "on_bootstrap_join_battle_request"),
		TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED: Callable(_network_gateway, "on_bootstrap_join_battle_accepted"),
		TransportMessageTypesScript.JOIN_BATTLE_REJECTED: Callable(_network_gateway, "on_bootstrap_join_battle_rejected"),
		TransportMessageTypesScript.BATTLE_ENTRY_REJECTED: Callable(_network_gateway, "on_bootstrap_join_battle_rejected"),
		TransportMessageTypesScript.INPUT_BATCH: Callable(_network_gateway, "on_bootstrap_input_frame_message"),
		TransportMessageTypesScript.INPUT_ACK: Callable(_network_gateway, "on_bootstrap_client_runtime_message"),
		TransportMessageTypesScript.STATE_SUMMARY: Callable(_network_gateway, "on_bootstrap_client_runtime_message"),
		TransportMessageTypesScript.STATE_DELTA: Callable(_network_gateway, "on_bootstrap_client_runtime_message"),
		TransportMessageTypesScript.CHECKPOINT: Callable(_network_gateway, "on_bootstrap_client_runtime_message"),
		TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT: Callable(_network_gateway, "on_bootstrap_client_runtime_message"),
		TransportMessageTypesScript.MATCH_START: Callable(_network_gateway, "on_bootstrap_match_start_message"),
		TransportMessageTypesScript.MATCH_FINISHED: Callable(_network_gateway, "on_bootstrap_match_finished_message"),
	}, Callable(_network_gateway, "on_bootstrap_unhandled_message"))


func _ensure_bootstrap_authority_runtime() -> void:
	_ensure_battle_session_bootstrap()
	_bootstrap_authority_runtime = _battle_session_bootstrap.ensure_authority_runtime()


func _ensure_bootstrap_client_runtime() -> void:
	_ensure_battle_session_bootstrap()
	_bootstrap_client_runtime = _battle_session_bootstrap.ensure_client_runtime()


func _ensure_battle_session_bootstrap() -> void:
	if _battle_session_bootstrap != null:
		return
	_battle_session_bootstrap = BattleSessionBootstrapScript.new()
	add_child(_battle_session_bootstrap)
	_battle_session_bootstrap.log_event.connect(func(message: String) -> void:
		network_log_event.emit(message)
	)
	_battle_session_bootstrap.host_match_started.connect(func(config: BattleStartConfig) -> void:
		network_host_match_started.emit(config)
	)
	_battle_session_bootstrap.client_config_accepted.connect(func(config: BattleStartConfig) -> void:
		start_config = config.duplicate_deep()
		network_client_match_started.emit(config)
	)
	_battle_session_bootstrap.client_prediction_event.connect(func(event: Dictionary) -> void:
		prediction_debug_event.emit(event)
	)
	_battle_session_bootstrap.client_battle_finished.connect(func(result: BattleResult) -> void:
		if network_mode == BattleNetworkMode.CLIENT:
			_finished_emitted = true
			_lifecycle_state = BattleLifecycleState.FINISHING
			battle_finished_authoritatively.emit(result)
	)
	_battle_session_bootstrap.network_battle_finished.connect(func(result: BattleResult, is_host: bool) -> void:
		network_battle_finished.emit(result, is_host)
	)
