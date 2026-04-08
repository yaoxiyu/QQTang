extends Node

const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const LocalLoopbackTransportScript = preload("res://network/transport/local_loopback_transport.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RemoteDebugInputDriverScript = preload("res://network/session/runtime/remote_debug_input_driver.gd")
const PredictionDivergenceDebuggerScript = preload("res://network/session/runtime/prediction_divergence_debugger.gd")
const BattleRuntimeMetricsBuilderScript = preload("res://network/session/runtime/battle_runtime_metrics_builder.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const RuntimeMessageRouterScript = preload("res://network/session/runtime/runtime_message_router.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")

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

const DEFAULT_MATCH_DURATION_TICKS: int = 180 * TickRunnerScript.TICK_RATE

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
var _runtime_metrics_builder: BattleRuntimeMetricsBuilder = BattleRuntimeMetricsBuilderScript.new()
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


func setup_from_start_config(config: BattleStartConfig) -> void:
	start_config = config.duplicate_deep() if config != null else null
	_lifecycle_state = BattleLifecycleState.IDLE if start_config != null else BattleLifecycleState.STOPPED


func start_battle() -> void:
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

	_shutdown_transport(false)

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
	if transport != null:
		return transport.cycle_latency_profile()
	return 0


func cycle_loss_profile() -> int:
	_ensure_transport_for_debug()
	if transport != null:
		return transport.cycle_loss_profile()
	return 0


func toggle_remote_debug_inputs() -> bool:
	use_remote_debug_inputs = not use_remote_debug_inputs
	return use_remote_debug_inputs


func arm_force_prediction_divergence() -> void:
	prediction_debug_event.emit(_prediction_debugger.arm())


func get_latency_profile_ms() -> int:
	_ensure_transport_for_debug()
	if transport != null:
		return transport.get_latency_profile_ms()
	return 0


func get_packet_loss_percent() -> int:
	_ensure_transport_for_debug()
	if transport != null:
		return transport.get_packet_loss_percent()
	return 0


func get_network_profile_summary() -> String:
	_ensure_transport_for_debug()
	if transport != null:
		return transport.get_network_profile_summary()
	return "0ms / 0%"


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

	_initialize_transport(profile)

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
	shutdown_battle()
	_ensure_bootstrap_client_runtime()
	start_config = config.duplicate_deep() if config != null else null
	if start_config == null:
		return false
	network_mode = BattleNetworkMode.CLIENT
	_bootstrap_local_peer_id = int(options.get("local_peer_id", int(start_config.local_peer_id if start_config != null else _bootstrap_local_peer_id)))
	var controlled_peer_id := int(options.get("controlled_peer_id", int(start_config.controlled_peer_id if start_config != null else _bootstrap_local_peer_id)))
	_bootstrap_client_runtime.configure(_bootstrap_local_peer_id)
	_bootstrap_client_runtime.configure_controlled_peer(controlled_peer_id)
	var client_started := _bootstrap_client_runtime.start_match(start_config)
	client_session = _bootstrap_client_runtime.client_session
	prediction_controller = _bootstrap_client_runtime.prediction_controller
	if not client_started or client_session == null or prediction_controller == null:
		return false
	_local_peer_id = _bootstrap_local_peer_id
	_finished_emitted = false
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1
	if not prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
		prediction_controller.prediction_corrected.connect(_on_prediction_corrected)
	if not prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
		prediction_controller.full_visual_resync.connect(_on_full_visual_resync)
	visual_sync_controller = VisualSyncController.new()
	add_child(visual_sync_controller)
	current_context = BattleContext.new()
	current_context.battle_start_config = start_config.duplicate_deep()
	current_context.sim_world = prediction_controller.predicted_sim_world
	current_context.tick_runner = prediction_controller.predicted_sim_world.tick_runner if prediction_controller.predicted_sim_world != null else null
	current_context.client_session = client_session
	current_context.prediction_controller = prediction_controller
	current_context.rollback_controller = prediction_controller.rollback_controller
	current_context.visual_sync_controller = visual_sync_controller
	adapter_configured.emit()
	return true


func _advance_client_runtime_tick(local_input: Dictionary = {}) -> void:
	if _bootstrap_client_runtime == null:
		return
	var app_runtime = get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else null
	if app_runtime == null or not app_runtime.has_method("apply_canonical_start_config"):
		app_runtime = null
	var room_runtime = app_runtime.client_room_runtime if app_runtime != null and app_runtime.client_room_runtime != null else null
	if room_runtime == null or not room_runtime.has_method("send_battle_input"):
		return
	var input_message := _bootstrap_client_runtime.build_local_input_message(local_input)
	if not input_message.is_empty():
		room_runtime.send_battle_input(input_message)
	_emit_client_runtime_tick()


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
	var authoritative_tick: int = current_context.sim_world.state.match_state.tick if current_context != null and current_context.sim_world != null else 0
	var snapshot_tick: int = client_session.latest_snapshot_tick if client_session != null else authoritative_tick
	var transport_stats := _get_transport_stats()
	var metrics := {
		"lifecycle_state": _lifecycle_state,
		"lifecycle_state_name": get_lifecycle_state_name(),
		"battle_active": is_battle_active(),
		"shutdown_complete": is_shutdown_complete(),
		"latency_ms": get_latency_profile_ms(),
		"packet_loss_percent": get_packet_loss_percent(),
		"ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"rollback_count": current_context.rollback_controller.rollback_count if current_context != null and current_context.rollback_controller != null else 0,
		"last_rollback_tick": current_context.rollback_controller.last_rollback_from_tick if current_context != null and current_context.rollback_controller != null else -1,
		"resync_count": current_context.rollback_controller.force_resync_count if current_context != null and current_context.rollback_controller != null else 0,
		"predicted_tick": prediction_controller.predicted_until_tick if prediction_controller != null else authoritative_tick,
		"authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else authoritative_tick,
		"snapshot_tick": snapshot_tick,
		"prediction_enabled": prediction_controller != null,
		"network_profile": get_network_profile_summary(),
		"force_divergence_armed": _prediction_debugger.is_armed(),
		"correction_count": _correction_count,
		"last_correction": _last_correction_summary,
		"last_resync_tick": _last_resync_tick,
		"drop_rate_percent": ItemSpawnSystemScript.get_debug_drop_rate_percent(),
		"remote_debug_inputs": use_remote_debug_inputs,
	}
	return _runtime_metrics_builder.build(metrics, transport_stats)


func ingest_dedicated_server_message(message: Dictionary) -> void:
	if _bootstrap_client_runtime == null or message.is_empty():
		return
	if network_mode != BattleNetworkMode.CLIENT:
		return
	_bootstrap_client_runtime.ingest_network_message(message)
	_emit_client_runtime_tick()
	if String(message.get("message_type", message.get("msg_type", ""))) == TransportMessageTypesScript.MATCH_FINISHED and current_context != null:
		_finished_emitted = true
		_lifecycle_state = BattleLifecycleState.FINISHING


func _emit_client_runtime_tick() -> void:
	if current_context == null or prediction_controller == null or current_context.sim_world == null:
		return
	current_context.sim_world = prediction_controller.predicted_sim_world
	current_context.tick_runner = prediction_controller.predicted_sim_world.tick_runner if prediction_controller.predicted_sim_world != null else null
	var world: SimWorld = current_context.sim_world
	var authoritative_events: Array = _bootstrap_client_runtime.consume_pending_authoritative_events() if _bootstrap_client_runtime != null and _bootstrap_client_runtime.has_method("consume_pending_authoritative_events") else []
	var tick_result := {
		"tick": world.state.match_state.tick if world != null else 0,
		"events": authoritative_events if not authoritative_events.is_empty() else (world.events.get_events() if world != null and world.events != null else []),
		"phase": world.state.match_state.phase if world != null else MatchState.Phase.PLAYING,
	}
	authoritative_tick_completed.emit(current_context, tick_result, _build_runtime_metrics())


func _build_predicted_world_from_authoritative(authoritative_match: BattleMatch) -> SimWorld:
	var predicted_world := SimWorld.new()
	var sim_config := BattleSimConfigBuilderScript.new().build_for_start_config(start_config)
	predicted_world.bootstrap(sim_config, {
			"grid": _build_grid_for_map(start_config.map_id),
			"player_slots": start_config.player_slots.duplicate(true),
			"spawn_assignments": start_config.spawn_assignments.duplicate(true),
		})
	if authoritative_match != null and authoritative_match.snapshot_service != null and authoritative_match.sim_world != null:
		var snapshot: WorldSnapshot = authoritative_match.snapshot_service.build_standard_snapshot(authoritative_match.sim_world, authoritative_match.sim_world.state.match_state.tick)
		authoritative_match.snapshot_service.restore_snapshot(predicted_world, snapshot)
	return predicted_world


func _build_grid_for_map(map_id: String):
	var grid := MapLoaderScript.build_grid_state(map_id)
	if grid != null:
		return grid
	push_error("MapLoader failed: %s" % map_id)
	return null


func _resolve_local_peer_id(config: BattleStartConfig) -> int:
	if config == null:
		return 1
	if int(config.local_peer_id) > 0:
		return int(config.local_peer_id)
	if config.players.is_empty():
		return 1
	return int(config.players[0].get("peer_id", 1))


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


func _resolve_local_slot(config: BattleStartConfig) -> int:
	if config == null:
		return 0
	for player_entry in config.players:
		if int(player_entry.get("peer_id", -1)) == _local_peer_id:
			return int(player_entry.get("slot_index", 0))
	return 0


func _resolve_match_duration_ticks(config: BattleStartConfig) -> int:
	if config == null:
		return DEFAULT_MATCH_DURATION_TICKS
	if int(config.match_duration_ticks) > 0:
		return int(config.match_duration_ticks)
	var rule_config := RuleSetCatalogScript.get_rule_metadata(String(config.rule_set_id))
	if rule_config.is_empty():
		push_error("Failed to load rule config: %s" % String(config.rule_set_id))
		return DEFAULT_MATCH_DURATION_TICKS
	var round_time_sec := int(rule_config.get("round_time_sec", 0))
	if round_time_sec <= 0:
		return DEFAULT_MATCH_DURATION_TICKS
	return round_time_sec * TickRunnerScript.TICK_RATE


func _validate_runtime_start_config(config: BattleStartConfig) -> bool:
	if config == null:
		push_error("Failed to start battle: missing BattleStartConfig")
		return false
	var map_id := String(config.map_id)
	var rule_id := String(config.rule_set_id)

	var map_config := MapLoaderScript.load_map_config(map_id)
	if map_config.is_empty():
		push_error("Failed to load map config: %s" % map_id)
		return false
	var rule_config := RuleSetCatalogScript.get_rule_metadata(rule_id)
	if rule_config.is_empty():
		push_error("Failed to load rule config: %s" % rule_id)
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
	if transport != null:
		return
	_initialize_transport({})


func _initialize_transport(debug_profile: Dictionary = {}) -> void:
	_shutdown_transport(false)

	var transport_config := {
		"is_server": true,
		"local_peer_id": _local_peer_id,
		"remote_peer_ids": _resolve_remote_peer_ids(start_config),
		"seed": int(start_config.battle_seed) ^ 0x51A7 if start_config != null else 0,
		"debug_profile": debug_profile,
		"host": network_host,
		"port": network_port,
		"max_clients": network_max_clients,
	}

	match network_mode:
		BattleNetworkMode.LOCAL_LOOPBACK:
			transport = LocalLoopbackTransportScript.new()
		BattleNetworkMode.HOST:
			transport = ENetBattleTransportScript.new()
			transport_config["is_server"] = true
		BattleNetworkMode.CLIENT:
			transport = ENetBattleTransportScript.new()
			transport_config["is_server"] = false
			transport_config["local_peer_id"] = 0
			transport_config["remote_peer_ids"] = []
		_:
			transport = LocalLoopbackTransportScript.new()

	if transport == null:
		return
	add_child(transport)
	_connect_transport_bridge_signals()
	transport.initialize(transport_config)


func _shutdown_transport(_emit_disconnect: bool) -> void:
	if transport == null or not is_instance_valid(transport):
		transport = null
		return
	transport.shutdown()
	if transport.get_parent() == self:
		remove_child(transport)
	transport.free()
	transport = null


func _capture_transport_profile() -> Dictionary:
	if transport != null and transport.has_method("export_debug_profile"):
		return transport.call("export_debug_profile")
	return {}


func _set_transport_tick(tick_id: int) -> void:
	if transport != null and transport.has_method("set_current_tick"):
		transport.call("set_current_tick", tick_id)


func _resolve_remote_peer_ids(config: BattleStartConfig) -> Array[int]:
	var remote_peer_ids: Array[int] = []
	if config == null:
		return remote_peer_ids
	for player_entry in config.players:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id < 0 or peer_id == _local_peer_id:
			continue
		remote_peer_ids.append(peer_id)
	return remote_peer_ids


func _get_transport_stats() -> Dictionary:
	if transport == null:
		return {
			"enqueued": 0,
			"delivered": 0,
			"dropped": 0,
			"pending": 0,
		}
	var stats := transport.get_debug_stats()
	if transport.has_method("get_pending_message_count"):
		stats["pending"] = int(transport.call("get_pending_message_count"))
	else:
		stats["pending"] = 0
	return stats


func network_bootstrap_configure_host(local_peer_id: int = 1) -> void:
	_ensure_bootstrap_authority_runtime()
	network_mode = BattleNetworkMode.HOST
	_bootstrap_local_peer_id = local_peer_id
	_bootstrap_authority_runtime.configure(local_peer_id)


func network_bootstrap_configure_client(local_peer_id: int = 0) -> void:
	_ensure_bootstrap_client_runtime()
	network_mode = BattleNetworkMode.CLIENT
	_bootstrap_local_peer_id = local_peer_id


func network_bootstrap_set_local_peer_id(local_peer_id: int) -> void:
	_bootstrap_local_peer_id = local_peer_id


func notify_dedicated_server_transport_connected() -> void:
	if network_mode != BattleNetworkMode.CLIENT:
		return
	network_transport_connected.emit()


func notify_dedicated_server_transport_disconnected() -> void:
	if network_mode != BattleNetworkMode.CLIENT:
		return
	network_transport_disconnected.emit()
	network_transport_error.emit(ERR_CONNECTION_ERROR, "Dedicated server transport disconnected")


func notify_dedicated_server_transport_error(error_code: String, user_message: String) -> void:
	if network_mode != BattleNetworkMode.CLIENT:
		return
	network_transport_error.emit(ERR_CONNECTION_ERROR, "%s: %s" % [error_code, user_message])


func network_bootstrap_start_host_match(config: BattleStartConfig) -> bool:
	return _start_runtime_session(BattleNetworkMode.HOST, config, {
		"local_peer_id": _bootstrap_local_peer_id,
	})


func network_bootstrap_build_start_config(snapshot: RoomSnapshot) -> BattleStartConfig:
	_ensure_bootstrap_coordinator()
	return _bootstrap_coordinator.build_start_config(snapshot)


func network_bootstrap_route_messages(messages: Array[Dictionary]) -> void:
	_ensure_runtime_message_router()
	_runtime_message_router.route_messages(messages)


func network_bootstrap_build_host_tick_messages(local_input: Dictionary = {}) -> Array[Dictionary]:
	if _bootstrap_authority_runtime == null:
		return []
	return _bootstrap_authority_runtime.advance_authoritative_tick(local_input)


func network_bootstrap_build_client_input_message(local_input: Dictionary = {}) -> Dictionary:
	if _bootstrap_client_runtime == null:
		return {}
	return _bootstrap_client_runtime.build_local_input_message(local_input)


func network_bootstrap_is_host_match_running() -> bool:
	return _bootstrap_authority_runtime != null and _bootstrap_authority_runtime.is_match_running()


func network_bootstrap_is_client_active() -> bool:
	return _bootstrap_client_runtime != null and _bootstrap_client_runtime.is_active()


func network_bootstrap_build_client_metrics() -> Dictionary:
	if _bootstrap_client_runtime == null:
		return {}
	return _bootstrap_client_runtime.build_metrics()


func network_bootstrap_shutdown() -> void:
	if _bootstrap_authority_runtime != null:
		_bootstrap_authority_runtime.shutdown_runtime()
		if is_instance_valid(_bootstrap_authority_runtime):
			_bootstrap_authority_runtime.queue_free()
		_bootstrap_authority_runtime = null
	if _bootstrap_client_runtime != null:
		_bootstrap_client_runtime.shutdown_runtime()
		if is_instance_valid(_bootstrap_client_runtime):
			_bootstrap_client_runtime.queue_free()
		_bootstrap_client_runtime = null
	if _bootstrap_coordinator != null:
		if is_instance_valid(_bootstrap_coordinator):
			_bootstrap_coordinator.queue_free()
		_bootstrap_coordinator = null
	if _runtime_message_router != null:
		if is_instance_valid(_runtime_message_router):
			_runtime_message_router.queue_free()
		_runtime_message_router = null
	_shutdown_transport(false)
	start_config = null
	_bootstrap_local_peer_id = 0


func network_bootstrap_start_host_transport(port: int, max_clients: int) -> void:
	_ensure_bootstrap_authority_runtime()
	network_port = port
	network_max_clients = max_clients
	network_mode = BattleNetworkMode.HOST
	_initialize_transport({})


func network_bootstrap_start_client_transport(host: String, port: int, connect_timeout_seconds: float = 5.0) -> void:
	_ensure_bootstrap_client_runtime()
	network_host = host
	network_port = port
	network_mode = BattleNetworkMode.CLIENT
	_initialize_transport({
		"connect_timeout_seconds": connect_timeout_seconds,
	})


func network_bootstrap_poll_transport() -> void:
	if transport == null:
		return
	transport.poll()
	network_bootstrap_route_messages(transport.consume_incoming())


func network_bootstrap_transport_connected() -> bool:
	return transport != null and transport.is_transport_connected()


func network_bootstrap_transport_remote_peer_ids() -> Array[int]:
	if transport == null:
		return []
	return transport.get_remote_peer_ids()


func network_bootstrap_transport_local_peer_id() -> int:
	if transport == null:
		return 0
	return transport.get_local_peer_id()


func network_bootstrap_send_to_peer(peer_id: int, message: Dictionary) -> void:
	if transport == null:
		return
	transport.send_to_peer(peer_id, message)


func network_bootstrap_broadcast(message: Dictionary) -> void:
	if transport == null:
		return
	transport.broadcast(message)


func _ensure_bootstrap_coordinator() -> void:
	if _bootstrap_coordinator == null:
		_bootstrap_coordinator = MatchStartCoordinatorScript.new()
		add_child(_bootstrap_coordinator)


func _ensure_runtime_message_router() -> void:
	if _runtime_message_router == null:
		_runtime_message_router = RuntimeMessageRouterScript.new()
		add_child(_runtime_message_router)
		_runtime_message_router.register_handler(TransportMessageTypesScript.JOIN_BATTLE_REQUEST, Callable(self, "_on_bootstrap_join_battle_request"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED, Callable(self, "_on_bootstrap_join_battle_accepted"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.JOIN_BATTLE_REJECTED, Callable(self, "_on_bootstrap_join_battle_rejected"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.INPUT_FRAME, Callable(self, "_on_bootstrap_input_frame_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.INPUT_ACK, Callable(self, "_on_bootstrap_client_runtime_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.STATE_SUMMARY, Callable(self, "_on_bootstrap_client_runtime_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.CHECKPOINT, Callable(self, "_on_bootstrap_client_runtime_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, Callable(self, "_on_bootstrap_client_runtime_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.MATCH_START, Callable(self, "_on_bootstrap_match_start_message"))
		_runtime_message_router.register_handler(TransportMessageTypesScript.MATCH_FINISHED, Callable(self, "_on_bootstrap_match_finished_message"))
		_runtime_message_router.set_fallback_handler(Callable(self, "_on_bootstrap_unhandled_message"))


func _ensure_bootstrap_authority_runtime() -> void:
	if _bootstrap_authority_runtime == null:
		_bootstrap_authority_runtime = AuthorityRuntimeScript.new()
		add_child(_bootstrap_authority_runtime)
		_bootstrap_authority_runtime.log_event.connect(func(message: String) -> void:
			network_log_event.emit(message)
		)
		_bootstrap_authority_runtime.match_started.connect(func(config: BattleStartConfig) -> void:
			network_host_match_started.emit(config)
		)
		_bootstrap_authority_runtime.battle_finished.connect(func(result: BattleResult) -> void:
			network_battle_finished.emit(result, true)
		)


func _ensure_bootstrap_client_runtime() -> void:
	if _bootstrap_client_runtime == null:
		_bootstrap_client_runtime = ClientRuntimeScript.new()
		add_child(_bootstrap_client_runtime)
		_bootstrap_client_runtime.log_event.connect(func(message: String) -> void:
			network_log_event.emit(message)
		)
		_bootstrap_client_runtime.config_accepted.connect(func(config: BattleStartConfig) -> void:
			start_config = config.duplicate_deep()
			network_client_match_started.emit(config)
		)
		_bootstrap_client_runtime.prediction_event.connect(func(event: Dictionary) -> void:
			prediction_debug_event.emit(event)
		)
		_bootstrap_client_runtime.battle_finished.connect(func(result: BattleResult) -> void:
			if network_mode == BattleNetworkMode.CLIENT:
				_finished_emitted = true
				_lifecycle_state = BattleLifecycleState.FINISHING
				battle_finished_authoritatively.emit(result)
			network_battle_finished.emit(result, false)
		)


func _connect_transport_bridge_signals() -> void:
	if transport == null:
		return
	if not transport.connected.is_connected(_on_transport_connected):
		transport.connected.connect(_on_transport_connected)
	if not transport.disconnected.is_connected(_on_transport_disconnected):
		transport.disconnected.connect(_on_transport_disconnected)
	if not transport.peer_connected.is_connected(_on_transport_peer_connected):
		transport.peer_connected.connect(_on_transport_peer_connected)
	if not transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
		transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	if not transport.transport_error.is_connected(_on_transport_error):
		transport.transport_error.connect(_on_transport_error)


func _on_transport_connected() -> void:
	network_transport_connected.emit()


func _on_transport_disconnected() -> void:
	network_transport_disconnected.emit()


func _on_transport_peer_connected(peer_id: int) -> void:
	network_transport_peer_connected.emit(peer_id)


func _on_transport_peer_disconnected(peer_id: int) -> void:
	network_transport_peer_disconnected.emit(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	network_transport_error.emit(code, message)


func _on_bootstrap_join_battle_request(message: Dictionary) -> void:
	if network_mode != BattleNetworkMode.HOST:
		return
	network_log_event.emit("Host received join request from peer %d" % int(message.get("sender_peer_id", -1)))


func _on_bootstrap_join_battle_accepted(message: Dictionary) -> void:
	if network_mode != BattleNetworkMode.CLIENT:
		return
	_ensure_bootstrap_coordinator()
	var config := BattleStartConfig.from_dict(message.get("start_config", {}))
	var validation: Dictionary = _bootstrap_coordinator.validate_start_config(config)
	if not bool(validation.get("ok", false)):
		network_log_event.emit("Client rejected config: %s" % str(validation.get("errors", [])))
		return
	_start_runtime_session(BattleNetworkMode.CLIENT, config, {
		"local_peer_id": _bootstrap_local_peer_id,
	})


func _on_bootstrap_join_battle_rejected(message: Dictionary) -> void:
	network_log_event.emit("Join rejected: %s" % str(message))


func _on_bootstrap_input_frame_message(message: Dictionary) -> void:
	if (network_mode == BattleNetworkMode.HOST or network_mode == BattleNetworkMode.LOCAL_LOOPBACK) and _bootstrap_authority_runtime != null:
		_bootstrap_authority_runtime.ingest_network_message(message)


func _on_bootstrap_client_runtime_message(message: Dictionary) -> void:
	if (network_mode == BattleNetworkMode.CLIENT or network_mode == BattleNetworkMode.LOCAL_LOOPBACK) and _bootstrap_client_runtime != null:
		_bootstrap_client_runtime.ingest_network_message(message)


func _on_bootstrap_match_start_message(_message: Dictionary) -> void:
	pass


func _on_bootstrap_match_finished_message(message: Dictionary) -> void:
	if (network_mode == BattleNetworkMode.CLIENT or network_mode == BattleNetworkMode.LOCAL_LOOPBACK) and _bootstrap_client_runtime != null:
		_bootstrap_client_runtime.ingest_network_message(message)


func _on_bootstrap_unhandled_message(message: Dictionary) -> void:
	if not message.is_empty():
		network_log_event.emit("Unhandled message %s" % str(message.get("message_type", message.get("msg_type", "unknown"))))
