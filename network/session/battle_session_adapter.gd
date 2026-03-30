extends Node

const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const LocalLoopbackTransportScript = preload("res://network/transport/local_loopback_transport.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RemoteDebugInputDriverScript = preload("res://network/session/runtime/remote_debug_input_driver.gd")
const PredictionDivergenceDebuggerScript = preload("res://network/session/runtime/prediction_divergence_debugger.gd")
const BattleRuntimeMetricsBuilderScript = preload("res://network/session/runtime/battle_runtime_metrics_builder.gd")

signal adapter_configured()
signal battle_session_started(config)
signal battle_context_created(context)
signal authoritative_tick_completed(context, tick_result, metrics)
signal battle_finished_authoritatively(result)
signal battle_session_stopped()
signal prediction_debug_event(event)

const DEFAULT_MATCH_DURATION_TICKS: int = 360

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


func bind_sessions(p_client_session: ClientSession, p_server_session: ServerSession) -> void:
	client_session = p_client_session
	server_session = p_server_session
	adapter_configured.emit()


func setup_from_start_config(config: BattleStartConfig) -> void:
	start_config = config.duplicate_deep() if config != null else null
	_lifecycle_state = BattleLifecycleState.IDLE if start_config != null else BattleLifecycleState.STOPPED


func start_battle() -> void:
	if start_config == null:
		return
	_lifecycle_state = BattleLifecycleState.STARTING
	_rebuild_runtime()
	if current_context == null:
		_lifecycle_state = BattleLifecycleState.STOPPED
		return
	_lifecycle_state = BattleLifecycleState.RUNNING
	battle_session_started.emit(start_config)
	battle_context_created.emit(current_context)


func advance_authoritative_tick(local_input: Dictionary = {}) -> void:
	if current_context == null or server_session == null or server_session.active_match == null:
		return
	if _finished_emitted:
		return

	var next_tick: int = server_session.active_match.sim_world.state.match_state.tick + 1
	_enqueue_local_input(next_tick, local_input)
	_enqueue_remote_inputs(next_tick)
	_flush_client_inputs_to_server()
	server_session.tick_once()
	_publish_server_messages(server_session.poll_messages(), next_tick)
	_poll_transport(next_tick)
	_apply_transport_messages(transport.consume_incoming() if transport != null else [])

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

	if prediction_controller != null:
		if prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
			prediction_controller.prediction_corrected.disconnect(_on_prediction_corrected)
		if prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
			prediction_controller.full_visual_resync.disconnect(_on_full_visual_resync)

	if current_context != null:
		current_context.clear_runtime_refs()

	_remote_debug_input_driver.shutdown()

	if prediction_controller != null:
		prediction_controller.dispose()
		if is_instance_valid(prediction_controller):
			prediction_controller.free()
	prediction_controller = null

	if visual_sync_controller != null and is_instance_valid(visual_sync_controller):
		visual_sync_controller.free()
	visual_sync_controller = null

	if client_session != null and is_instance_valid(client_session):
		client_session.free()
	client_session = null

	if server_session != null and is_instance_valid(server_session):
		server_session.free()
	server_session = null

	_shutdown_transport(false)

	current_context = null
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


func _rebuild_runtime() -> void:
	var profile := _capture_transport_profile()
	shutdown_battle()
	if start_config == null:
		return

	_local_peer_id = _resolve_local_peer_id(start_config)
	_finished_emitted = false
	_prediction_debugger.clear()
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1

	server_session = ServerSession.new()
	add_child(server_session)

	client_session = ClientSession.new()
	client_session.configure(_local_peer_id)
	add_child(client_session)

	_remote_debug_input_driver.setup(self, start_config, _local_peer_id)

	_initialize_transport(profile)

	server_session.create_room(start_config.room_id, start_config.map_id, start_config.rule_set_id)
	for player_entry in start_config.players:
		var peer_id: int = int(player_entry.get("peer_id", -1))
		if peer_id < 0:
			continue
		server_session.add_peer(peer_id)
		server_session.set_peer_ready(peer_id, true)

	var started: bool = server_session.start_match(
		SimConfig.new(),
		{
			"grid": _build_grid_for_map(start_config.map_id),
			"player_slots": start_config.player_slots.duplicate(true),
			"spawn_assignments": start_config.spawn_assignments.duplicate(true),
		},
		start_config.battle_seed,
		start_config.start_tick
	)
	if not started or server_session.active_match == null:
		_lifecycle_state = BattleLifecycleState.STOPPED
		return

	server_session.active_match.sim_world.state.match_state.remaining_ticks = _resolve_match_duration_ticks(start_config)
	server_session.active_match.sim_world.state.match_state.phase = MatchState.Phase.PLAYING

	prediction_controller = PredictionController.new()
	add_child(prediction_controller)
	visual_sync_controller = VisualSyncController.new()
	add_child(visual_sync_controller)

	var predicted_world: SimWorld = _build_predicted_world_from_authoritative(server_session.active_match)
	prediction_controller.configure(
		predicted_world,
		server_session.active_match.snapshot_service,
		client_session.local_input_buffer,
		_resolve_local_slot(start_config)
	)
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


func _enqueue_local_input(tick_id: int, local_input: Dictionary) -> void:
	if client_session == null:
		return
	var move_x: int = clamp(int(local_input.get("move_x", 0)), -1, 1)
	var move_y: int = clamp(int(local_input.get("move_y", 0)), -1, 1)
	var action_place: bool = bool(local_input.get("action_place", false))
	var frame: PlayerInputFrame = client_session.sample_input_for_tick(tick_id, move_x, move_y, action_place)
	client_session.send_input(frame)
	if prediction_controller != null:
		prediction_controller.predict_to_tick(tick_id)


func _enqueue_remote_inputs(tick_id: int) -> void:
	_remote_debug_input_driver.enqueue_inputs(tick_id, use_remote_debug_inputs)


func _flush_client_inputs_to_server() -> void:
	if server_session == null:
		return
	if client_session != null:
		for frame in client_session.flush_outgoing_inputs():
			server_session.receive_input(frame)
	_remote_debug_input_driver.flush_to_server(server_session)


func _publish_server_messages(messages: Array, server_tick: int) -> void:
	if transport == null:
		return
	_set_transport_tick(server_tick)
	for message in messages:
		transport.send_to_peer(_local_peer_id, message)


func _poll_transport(current_tick: int) -> void:
	if transport == null:
		return
	_set_transport_tick(current_tick)
	transport.poll()


func _apply_transport_messages(messages: Array) -> void:
	for message in messages:
		var msg_type: String = str(message.get("msg_type", ""))
		match msg_type:
			TransportMessageTypesScript.INPUT_ACK:
				if client_session != null and int(message.get("peer_id", -1)) == client_session.local_peer_id:
					client_session.on_input_ack(int(message.get("ack_tick", 0)))
			TransportMessageTypesScript.STATE_SUMMARY:
				if client_session != null:
					client_session.on_state_summary(message)
			TransportMessageTypesScript.CHECKPOINT:
				if client_session != null:
					client_session.on_snapshot(message)
				if prediction_controller != null and server_session != null and server_session.active_match != null:
					var snapshot: WorldSnapshot = server_session.active_match.get_snapshot(int(message.get("tick", 0)))
					if snapshot == null:
						snapshot = server_session.active_match.snapshot_service.build_light_snapshot(
							server_session.active_match.sim_world,
							int(message.get("tick", 0))
						)
					if _prediction_debugger.is_armed():
						var debug_event := _prediction_debugger.inject(snapshot, prediction_controller)
						if not debug_event.is_empty():
							prediction_debug_event.emit(debug_event)
					prediction_controller.on_authoritative_snapshot(snapshot)
			_:
				pass


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


func _build_predicted_world_from_authoritative(authoritative_match: BattleMatch) -> SimWorld:
	var predicted_world := SimWorld.new()
	predicted_world.bootstrap(SimConfig.new(), {
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
	push_warning("MapLoader failed for %s, falling back to TestMapFactory" % map_id)
	return TestMapFactory.build_basic_map()


func _resolve_local_peer_id(config: BattleStartConfig) -> int:
	if config == null or config.players.is_empty():
		return 1
	return int(config.players[0].get("peer_id", 1))


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
	match str(config.rule_set_id):
		"team":
			return 480
		_:
			return DEFAULT_MATCH_DURATION_TICKS


func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	_correction_count += 1
	_last_correction_summary = "E%d %s -> %s" % [entity_id, str(from_pos), str(to_pos)]
	prediction_debug_event.emit({
		"type": "prediction_corrected",
		"entity_id": entity_id,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"message": "Rollback corrected E%d %s -> %s" % [entity_id, str(from_pos), str(to_pos)],
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
