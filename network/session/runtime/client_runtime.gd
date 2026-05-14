class_name ClientRuntime
extends Node

const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const ClientRuntimeSnapshotApplierScript = preload("res://network/session/runtime/client_runtime_snapshot_applier.gd")
const ClientRuntimeResumeCoordinatorScript = preload("res://network/session/runtime/client_runtime_resume_coordinator.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const ClientInputBatchBuilderScript = preload("res://network/session/runtime/client_input_batch_builder.gd")
const ClientAuthorityIngestionScript = preload("res://network/session/runtime/client_authority_ingestion.gd")
const ClientPredictionPolicyScript = preload("res://network/session/runtime/client_prediction_policy.gd")
const ClientRuntimeShutdownHandleScript = preload("res://network/session/runtime/client_runtime_shutdown_handle.gd")
const RuntimeShutdownContextScript = preload("res://app/runtime/runtime_shutdown_context.gd")
const RollbackTelemetryScript = preload("res://network/session/runtime/rollback_telemetry.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const TRACE_TAG := "sync.trace"

signal config_accepted(config: BattleStartConfig)
signal prediction_event(event: Dictionary)
signal battle_finished(result: BattleResult)
signal log_event(message: String)

var start_config: BattleStartConfig = null
var local_peer_id: int = 0
var controlled_peer_id: int = 0
var client_session: ClientSession = null
var prediction_controller: PredictionController = null
var snapshot_service: SnapshotService = null
var _correction_count: int = 0
var _last_resync_tick: int = -1
var _active: bool = false
var _finished: bool = false
var latest_authoritative_events: Array = []
var pending_authoritative_events_by_tick: Dictionary = {}
var _resume_coordinator: RefCounted = ClientRuntimeResumeCoordinatorScript.new()
var _input_batch_builder: RefCounted = ClientInputBatchBuilderScript.new()
var _authority_ingestion: RefCounted = ClientAuthorityIngestionScript.new()
var _prediction_policy: RefCounted = ClientPredictionPolicyScript.new()
var _shutdown_handle: RefCounted = ClientRuntimeShutdownHandleScript.new()


func configure(peer_id: int) -> void:
	local_peer_id = peer_id


func configure_controlled_peer(peer_id: int) -> void:
	controlled_peer_id = peer_id


func start_match(config: BattleStartConfig) -> bool:
	shutdown_runtime()
	if config == null:
		return false

	start_config = config.duplicate_deep()
	_prediction_policy.configure(start_config, prediction_controller)
	controlled_peer_id = int(start_config.controlled_peer_id) if start_config != null and int(start_config.controlled_peer_id) > 0 else local_peer_id
	client_session = ClientSession.new()
	client_session.configure(local_peer_id, controlled_peer_id)
	add_child(client_session)
	_input_batch_builder.configure(
		local_peer_id,
		controlled_peer_id,
		int(start_config.protocol_version),
		String(start_config.match_id)
	)
	snapshot_service = SnapshotService.new()
	prediction_controller = PredictionController.new()
	_prediction_policy.configure(start_config, prediction_controller)
	add_child(prediction_controller)

	var predicted_world := SimWorld.new()
	var sim_config := BattleSimConfigBuilderScript.new().build_for_start_config(start_config)
	predicted_world.bootstrap(sim_config, {
		"grid": MapLoaderScript.build_grid_state(start_config.map_id),
		"player_slots": start_config.player_slots.duplicate(true),
		"spawn_assignments": start_config.spawn_assignments.duplicate(true),
	})
	predicted_world.state.match_state.remaining_ticks = int(start_config.match_duration_ticks)
	predicted_world.state.match_state.phase = MatchState.Phase.PLAYING
	_mark_predicted_players_as_network(predicted_world)
	var controlled_slot := _resolve_controlled_slot(start_config)
	predicted_world.state.runtime_flags.client_prediction_mode = true
	predicted_world.state.runtime_flags.client_controlled_player_slot = controlled_slot
	predicted_world.state.runtime_flags.suppress_authority_entity_side_effects = _should_suppress_authority_only_entity_prediction()
	prediction_controller.configure(
		predicted_world,
		snapshot_service,
		client_session.local_input_buffer,
		controlled_slot,
		_should_compare_authority_only_entities_in_rollback(),
		_should_compare_authority_only_entities_in_rollback(),
		_resolve_ignored_local_player_keys_for_rollback()
	)
	if not prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
		prediction_controller.prediction_corrected.connect(_on_prediction_corrected)
	if not prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
		prediction_controller.full_visual_resync.connect(_on_full_visual_resync)

	_active = true
	_finished = false
	config_accepted.emit(start_config)
	log_event.emit("ClientRuntime accepted %s" % start_config.to_log_string())
	return true


func build_local_input_message(local_input: Dictionary = {}) -> Dictionary:
	if not _active or _finished or client_session == null:
		return {}
	var next_tick := _resolve_next_local_input_tick()
	var requested_bits := int(local_input.get("action_bits", 0))
	var effective_bits: int = _input_batch_builder.resolve_effective_action_bits(
		requested_bits,
		next_tick,
		_resume_coordinator,
		prediction_controller.predicted_sim_world if prediction_controller != null else null
	)
	var frame := client_session.sample_input_for_tick(
		next_tick,
		clamp(int(local_input.get("move_x", 0)), -1, 1),
		clamp(int(local_input.get("move_y", 0)), -1, 1),
		effective_bits
	)
	var prediction_frame: PlayerInputFrame = _build_prediction_frame(frame)
	client_session.send_input(frame, prediction_frame)
	if (frame.action_bits & PlayerInputFrame.BIT_PLACE) != 0:
		_resume_coordinator.track_local_place_request(prediction_controller.predicted_sim_world if prediction_controller != null else null, frame.tick_id)
	if prediction_controller != null:
		prediction_controller.predict_to_tick(next_tick)
	return _input_batch_builder.build_batch(client_session, frame)


func _resolve_next_local_input_tick() -> int:
	var predicted_next_tick := prediction_controller.predicted_until_tick + 1 if prediction_controller != null else client_session.last_confirmed_tick + 1
	if start_config == null:
		return predicted_next_tick
	var lead_ticks := int(start_config.network_input_lead_ticks)
	if prediction_controller == null:
		return predicted_next_tick
	lead_ticks = _resolve_runtime_input_lead_ticks()
	var authority_based_tick := int(prediction_controller.authoritative_tick) + lead_ticks
	return max(predicted_next_tick, authority_based_tick)


func _resolve_runtime_input_lead_ticks() -> int:
	return _prediction_policy.resolve_runtime_input_lead_ticks()


func _is_dedicated_opening_lead_window() -> bool:
	return _prediction_policy.is_dedicated_opening_lead_window()


func _build_prediction_frame(frame: PlayerInputFrame) -> PlayerInputFrame:
	if frame == null:
		return null
	var prediction_frame: PlayerInputFrame = frame.duplicate_for_tick(frame.tick_id)
	if _should_suppress_place_prediction():
		prediction_frame.action_bits = 0
	return prediction_frame


func _should_suppress_place_prediction() -> bool:
	return _prediction_policy.should_suppress_place_prediction()


func _should_suppress_authority_only_entity_prediction() -> bool:
	return _prediction_policy.should_suppress_authority_only_entity_prediction()


func _should_compare_authority_only_entities_in_rollback() -> bool:
	return _prediction_policy.should_compare_authority_only_entities_in_rollback()


func _should_apply_authority_sideband_to_current_world(message_tick: int) -> bool:
	return _resume_coordinator.should_apply_authority_sideband(
		prediction_controller.predicted_sim_world if prediction_controller != null else null,
		_should_suppress_authority_only_entity_prediction(),
		message_tick
	)


func ingest_network_message(message: Dictionary) -> void:
	_authority_ingestion.configure(self)
	_authority_ingestion.ingest_network_message(message)


func build_authority_cursor() -> Dictionary:
	return {
		"latest_authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else 0,
		"latest_snapshot_tick": client_session.latest_snapshot_tick if client_session != null else 0,
		"last_ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"predicted_until_tick": prediction_controller.predicted_until_tick if prediction_controller != null else 0,
		"controlled_peer_id": controlled_peer_id,
		"local_peer_id": local_peer_id,
		"last_consumed_event_tick": _authority_ingestion.get_last_consumed_event_tick(),
	}


func ingest_authority_batch(batch: Dictionary) -> void:
	_authority_ingestion.configure(self)
	_authority_ingestion.ingest_authority_batch(batch)


func get_last_authority_batch_metrics() -> Dictionary:
	return _authority_ingestion.get_last_authority_batch_metrics()


func build_metrics() -> Dictionary:
	var rollback_metrics := _build_rollback_metrics()
	var input_batch_metrics: Dictionary = _input_batch_builder.get_metrics()
	var metrics := {
		"ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"snapshot_tick": client_session.latest_snapshot_tick if client_session != null else 0,
		"predicted_tick": prediction_controller.predicted_until_tick if prediction_controller != null else 0,
		"authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else 0,
		"rollback_count": int(rollback_metrics.get("rollback_count", 0)),
		"resync_count": int(rollback_metrics.get("resync_count", 0)),
		"correction_count": _correction_count,
		"last_resync_tick": _last_resync_tick,
		"authority_batch": get_last_authority_batch_metrics(),
		"rollback": rollback_metrics,
		"input_lead_ticks": _resolve_runtime_input_lead_ticks() if start_config != null and prediction_controller != null else 0,
		"stale_input_ack_count": client_session.stale_input_ack_count if client_session != null else 0,
		"breakable_sync": get_breakable_sync_status(),
	}
	metrics.merge(input_batch_metrics, true)
	return metrics


func _build_rollback_metrics() -> Dictionary:
	if prediction_controller == null or prediction_controller.rollback_controller == null:
		return {
			"rollback_count": 0,
			"resync_count": 0,
			"last_rollback_from_tick": -1,
			"last_replay_tick_count": 0,
			"total_replay_ticks": 0,
			"avg_replay_ticks": 0.0,
			"native": {},
		}
	var rollback := prediction_controller.rollback_controller
	return {
		"rollback_count": rollback.rollback_count,
		"resync_count": rollback.force_resync_count,
		"last_rollback_from_tick": rollback.last_rollback_from_tick,
		"last_replay_tick_count": rollback.last_replay_tick_count,
		"total_replay_ticks": rollback.total_replay_ticks,
		"avg_replay_ticks": rollback.avg_replay_ticks,
		"native": rollback.get_native_rollback_metrics(),
	}


func is_active() -> bool:
	return _active and not _finished


func shutdown_runtime() -> void:
	_shutdown_handle.configure(self)
	_shutdown_handle.shutdown(RuntimeShutdownContextScript.new("client_runtime_shutdown", false))


func get_shutdown_name() -> String:
	_shutdown_handle.configure(self)
	return _shutdown_handle.get_shutdown_name()


func get_shutdown_priority() -> int:
	_shutdown_handle.configure(self)
	return _shutdown_handle.get_shutdown_priority()


func shutdown(_context: Variant) -> void:
	_shutdown_handle.configure(self)
	_shutdown_handle.shutdown(_context)


func _shutdown_runtime_internal(_context: Variant) -> void:
	_active = false
	_finished = false
	start_config = null
	if prediction_controller != null:
		prediction_controller.dispose()
		if is_instance_valid(prediction_controller):
			prediction_controller.free()
	prediction_controller = null
	if client_session != null and is_instance_valid(client_session):
		client_session.free()
	client_session = null
	snapshot_service = null
	controlled_peer_id = 0
	_correction_count = 0
	_last_resync_tick = -1
	RollbackTelemetryScript.reset_shared()
	latest_authoritative_events.clear()
	pending_authoritative_events_by_tick.clear()
	_authority_ingestion.reset()
	_resume_coordinator.reset()
	_input_batch_builder.reset()
	_prediction_policy.reset()


func get_shutdown_metrics() -> Dictionary:
	return _build_shutdown_metrics()


func _build_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"active": _active,
		"has_client_session": client_session != null,
		"has_prediction_controller": prediction_controller != null,
	}


# LegacyMigration: Inject resume checkpoint for battle recovery
func inject_resume_checkpoint_message(message: Dictionary) -> void:
	if message.is_empty():
		return
	ingest_network_message(message)


func _resolve_controlled_slot(config: BattleStartConfig) -> int:
	if config == null:
		return 0
	var resolved_peer_id := controlled_peer_id if controlled_peer_id > 0 else local_peer_id
	for player_entry in config.player_slots:
		if int(player_entry.get("peer_id", -1)) == resolved_peer_id:
			return int(player_entry.get("slot_index", 0))
	return 0


func _mark_predicted_players_as_network(predicted_world: SimWorld) -> void:
	if predicted_world == null:
		return
	for player_id in predicted_world.state.players.active_ids:
		var player := predicted_world.state.players.get_player(player_id)
		if player == null:
			continue
		player.controller_type = PlayerState.ControllerType.NETWORK
		predicted_world.state.players.update_player(player)


func consume_pending_authoritative_events() -> Array:
	_authority_ingestion.configure(self)
	return _authority_ingestion.consume_pending_authoritative_events()


func get_breakable_sync_status() -> Dictionary:
	_authority_ingestion.configure(self)
	if prediction_controller == null or prediction_controller.predicted_sim_world == null:
		return {"in_sync": true, "server_count": -1, "local_count": -1}
	return _authority_ingestion.get_breakable_sync_status(prediction_controller.predicted_sim_world)


func _resolve_ignored_local_player_keys_for_rollback() -> Array[String]:
	return _prediction_policy.resolve_ignored_local_player_keys_for_rollback()


func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	_correction_count += 1
	RollbackTelemetryScript.shared().record_correction(from_pos, to_pos)
	RollbackTelemetryScript.shared().flush_if_due()
	LogSyncScript.debug(
		"rollback_corrected entity=%d from=%s to=%s correction_count=%d last_resync_tick=%d" % [
			entity_id,
			str(from_pos),
			str(to_pos),
			_correction_count,
			_last_resync_tick,
		],
		"",
		0,
		"%s sync.client_runtime.rollback" % TRACE_TAG
	)
	prediction_event.emit({
		"type": "prediction_corrected",
		"entity_id": entity_id,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"message": "Client correction(fp) E%d %s -> %s" % [entity_id, str(from_pos), str(to_pos)],
	})


func _on_full_visual_resync(snapshot: WorldSnapshot) -> void:
	_last_resync_tick = snapshot.tick_id if snapshot != null else -1
	prediction_event.emit({
		"type": "full_resync",
		"tick": _last_resync_tick,
		"message": "Client full resync at tick %d" % _last_resync_tick,
	})
