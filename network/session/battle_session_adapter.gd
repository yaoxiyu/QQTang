extends Node

const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")

signal adapter_configured()
signal battle_session_started(config)
signal battle_context_created(context)
signal authoritative_tick_completed(context, tick_result, metrics)
signal battle_finished_authoritatively(result)
signal battle_session_stopped()
signal prediction_debug_event(event)

const DEFAULT_MATCH_DURATION_TICKS: int = 360
const LATENCY_PROFILES_MS: Array[int] = [0, 80, 150, 250]
const LOSS_PROFILES: Array[float] = [0.0, 0.05, 0.10, 0.20]

enum BattleLifecycleState {
	IDLE,
	STARTING,
	RUNNING,
	FINISHING,
	SHUTTING_DOWN,
	STOPPED,
}

var start_config: BattleStartConfig = null
var client_session: ClientSession = null
var server_session: ServerSession = null
var prediction_controller: PredictionController = null
var visual_sync_controller: VisualSyncController = null
var current_context: BattleContext = null

var _remote_clients: Array = []
var use_remote_debug_inputs: bool = false
var _local_peer_id: int = 0
var _finished_emitted: bool = false
var _latency_profile_index: int = 0
var _loss_profile_index: int = 0
var _delayed_server_messages: Array[Dictionary] = []
var _transport_stats: Dictionary = {
	"enqueued": 0,
	"delivered": 0,
	"dropped": 0,
}
var _message_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _force_prediction_divergence_pending: bool = false
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
	_buffer_server_messages(server_session.poll_messages(), next_tick)
	_apply_server_messages(_drain_deliverable_messages(next_tick))

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

	for remote_client in _remote_clients:
		if remote_client != null and is_instance_valid(remote_client):
			remote_client.free()
	_remote_clients.clear()

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

	current_context = null
	_local_peer_id = 0
	_finished_emitted = false
	_delayed_server_messages.clear()
	_force_prediction_divergence_pending = false
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1
	_reset_transport_stats()
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
	_latency_profile_index = (_latency_profile_index + 1) % LATENCY_PROFILES_MS.size()
	return get_latency_profile_ms()


func cycle_loss_profile() -> int:
	_loss_profile_index = (_loss_profile_index + 1) % LOSS_PROFILES.size()
	return get_packet_loss_percent()


func toggle_remote_debug_inputs() -> bool:
	use_remote_debug_inputs = not use_remote_debug_inputs
	return use_remote_debug_inputs


func arm_force_prediction_divergence() -> void:
	_force_prediction_divergence_pending = true
	prediction_debug_event.emit({
		"type": "force_divergence_armed",
		"message": "Forced prediction divergence armed",
	})


func get_latency_profile_ms() -> int:
	return LATENCY_PROFILES_MS[_latency_profile_index]


func get_packet_loss_percent() -> int:
	return int(round(LOSS_PROFILES[_loss_profile_index] * 100.0))


func get_network_profile_summary() -> String:
	return "%dms / %d%%" % [get_latency_profile_ms(), get_packet_loss_percent()]


func build_runtime_metrics_snapshot() -> Dictionary:
	return _build_runtime_metrics()


func _rebuild_runtime() -> void:
	shutdown_battle()
	if start_config == null:
		return

	_local_peer_id = _resolve_local_peer_id(start_config)
	_finished_emitted = false
	_delayed_server_messages.clear()
	_force_prediction_divergence_pending = false
	_correction_count = 0
	_last_correction_summary = ""
	_last_resync_tick = -1
	_reset_transport_stats()
	_message_rng.seed = int(start_config.seed) ^ 0x51A7

	server_session = ServerSession.new()
	add_child(server_session)

	client_session = ClientSession.new()
	client_session.configure(_local_peer_id)
	add_child(client_session)

	for player_entry in start_config.players:
		var peer_id: int = int(player_entry.get("peer_id", -1))
		if peer_id < 0 or peer_id == _local_peer_id:
			continue
		var remote_client := ClientSession.new()
		remote_client.configure(peer_id)
		add_child(remote_client)
		_remote_clients.append(remote_client)

	server_session.create_room(start_config.room_id, start_config.map_id, start_config.rule_set_id)
	for player_entry in start_config.players:
		var peer_id: int = int(player_entry.get("peer_id", -1))
		if peer_id < 0:
			continue
		server_session.add_peer(peer_id)
		server_session.set_peer_ready(peer_id, true)

	var started: bool = server_session.start_match(
		SimConfig.new(),
		{"grid": _build_grid_for_map(start_config.map_id)},
		start_config.seed,
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
	if not use_remote_debug_inputs:
		for remote_client in _remote_clients:
			if remote_client == null:
				continue
			remote_client.send_input(remote_client.sample_input_for_tick(tick_id, 0, 0, false))
		return

	for remote_client in _remote_clients:
		if remote_client == null:
			continue
		var remote_input: Dictionary = _sample_remote_debug_input(remote_client.local_peer_id, tick_id)
		remote_client.send_input(
			remote_client.sample_input_for_tick(
				tick_id,
				int(remote_input.get("move_x", 0)),
				int(remote_input.get("move_y", 0)),
				bool(remote_input.get("action_place", false))
			)
		)


func _flush_client_inputs_to_server() -> void:
	if server_session == null:
		return
	if client_session != null:
		for frame in client_session.flush_outgoing_inputs():
			server_session.receive_input(frame)
	for remote_client in _remote_clients:
		if remote_client == null:
			continue
		for frame in remote_client.flush_outgoing_inputs():
			server_session.receive_input(frame)


func _buffer_server_messages(messages: Array, server_tick: int) -> void:
	for message in messages:
		var msg_type: String = str(message.get("msg_type", ""))
		if _should_drop_server_message(msg_type):
			_transport_stats["dropped"] = int(_transport_stats.get("dropped", 0)) + 1
			continue
		var deliver_tick: int = server_tick + _current_latency_ticks()
		_delayed_server_messages.append({
			"deliver_tick": deliver_tick,
			"message": message.duplicate(true),
		})
		_transport_stats["enqueued"] = int(_transport_stats.get("enqueued", 0)) + 1


func _drain_deliverable_messages(current_tick: int) -> Array:
	var deliverable: Array = []
	var pending: Array[Dictionary] = []
	for entry in _delayed_server_messages:
		if int(entry.get("deliver_tick", 0)) <= current_tick:
			deliverable.append(entry.get("message", {}))
			_transport_stats["delivered"] = int(_transport_stats.get("delivered", 0)) + 1
		else:
			pending.append(entry)
	_delayed_server_messages = pending
	return deliverable


func _apply_server_messages(messages: Array) -> void:
	for message in messages:
		var msg_type: String = str(message.get("msg_type", ""))
		match msg_type:
			"INPUT_ACK":
				if client_session != null and int(message.get("peer_id", -1)) == client_session.local_peer_id:
					client_session.on_input_ack(int(message.get("ack_tick", 0)))
			"STATE_SUMMARY":
				if client_session != null:
					client_session.on_state_summary(message)
			"CHECKPOINT":
				if client_session != null:
					client_session.on_snapshot(message)
				if prediction_controller != null and server_session != null and server_session.active_match != null:
					var snapshot: WorldSnapshot = server_session.active_match.get_snapshot(int(message.get("tick", 0)))
					if snapshot == null:
						snapshot = server_session.active_match.snapshot_service.build_light_snapshot(
							server_session.active_match.sim_world,
							int(message.get("tick", 0))
						)
					if _force_prediction_divergence_pending:
						_inject_prediction_divergence(snapshot)
					prediction_controller.on_authoritative_snapshot(snapshot)
			_:
				pass


func _build_runtime_metrics() -> Dictionary:
	var authoritative_tick: int = current_context.sim_world.state.match_state.tick if current_context != null and current_context.sim_world != null else 0
	var snapshot_tick: int = client_session.latest_snapshot_tick if client_session != null else authoritative_tick
	return {
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
		"delivered_messages": int(_transport_stats.get("delivered", 0)),
		"dropped_messages": int(_transport_stats.get("dropped", 0)),
		"pending_server_messages": _delayed_server_messages.size(),
		"prediction_enabled": prediction_controller != null,
		"network_profile": get_network_profile_summary(),
		"force_divergence_armed": _force_prediction_divergence_pending,
		"correction_count": _correction_count,
		"last_correction": _last_correction_summary,
		"last_resync_tick": _last_resync_tick,
		"drop_rate_percent": ItemSpawnSystemScript.get_debug_drop_rate_percent(),
		"remote_debug_inputs": use_remote_debug_inputs,
	}


func _build_predicted_world_from_authoritative(authoritative_match: BattleMatch) -> SimWorld:
	var predicted_world := SimWorld.new()
	predicted_world.bootstrap(SimConfig.new(), {"grid": _build_grid_for_map(start_config.map_id)})
	if authoritative_match != null and authoritative_match.snapshot_service != null and authoritative_match.sim_world != null:
		var snapshot: WorldSnapshot = authoritative_match.snapshot_service.build_standard_snapshot(authoritative_match.sim_world, authoritative_match.sim_world.state.match_state.tick)
		authoritative_match.snapshot_service.restore_snapshot(predicted_world, snapshot)
	return predicted_world


func _build_grid_for_map(_map_id: String):
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
	match str(config.rule_set_id):
		"team":
			return 480
		_:
			return DEFAULT_MATCH_DURATION_TICKS


func _sample_remote_debug_input(peer_id: int, tick_id: int) -> Dictionary:
	var phase: int = int((tick_id / 24 + peer_id) % 4)
	var move_x: int = 0
	var move_y: int = 0
	match phase:
		0:
			move_x = 1
		1:
			move_y = 1
		2:
			move_x = -1
		3:
			move_y = -1
	var action_place: bool = tick_id > 20 and tick_id % 45 == (peer_id % 5)
	return {
		"move_x": move_x,
		"move_y": move_y,
		"action_place": action_place,
	}


func _current_latency_ticks() -> int:
	return int(ceil(float(get_latency_profile_ms()) / (TickRunnerScript.TICK_DT * 1000.0)))


func _should_drop_server_message(msg_type: String) -> bool:
	if msg_type.is_empty():
		return false
	if msg_type != "STATE_SUMMARY" and msg_type != "CHECKPOINT" and msg_type != "INPUT_ACK":
		return false
	return LOSS_PROFILES[_loss_profile_index] > 0.0 and _message_rng.randf() < LOSS_PROFILES[_loss_profile_index]


func _inject_prediction_divergence(snapshot: WorldSnapshot) -> void:
	_force_prediction_divergence_pending = false
	if snapshot == null or prediction_controller == null or prediction_controller.rollback_controller == null:
		return

	var local_snapshot: WorldSnapshot = prediction_controller.rollback_controller.snapshot_buffer.get_snapshot(snapshot.tick_id)
	if local_snapshot != null and not local_snapshot.players.is_empty():
		var first_player: Dictionary = local_snapshot.players[0]
		first_player["cell_x"] = int(first_player.get("cell_x", 0)) + 1
		first_player["offset_x"] = 0
		local_snapshot.players[0] = first_player
		local_snapshot.checksum += 1

	var predicted_world: SimWorld = prediction_controller.predicted_sim_world
	if predicted_world != null and not predicted_world.state.players.active_ids.is_empty():
		var player_id: int = predicted_world.state.players.active_ids[0]
		var player: PlayerState = predicted_world.state.players.get_player(player_id)
		if player != null:
			player.cell_x = min(player.cell_x + 1, predicted_world.state.grid.width - 2)
			predicted_world.state.players.update_player(player)
			predicted_world.rebuild_runtime_indexes()

	prediction_debug_event.emit({
		"type": "forced_divergence",
		"tick": snapshot.tick_id,
		"message": "Injected prediction divergence at tick %d" % snapshot.tick_id,
	})


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


func _reset_transport_stats() -> void:
	_transport_stats = {
		"enqueued": 0,
		"delivered": 0,
		"dropped": 0,
	}
