class_name ClientRuntime
extends Node

const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const ClientRuntimeSnapshotApplierScript = preload("res://network/session/runtime/client_runtime_snapshot_applier.gd")
const ClientRuntimeResumeCoordinatorScript = preload("res://network/session/runtime/client_runtime_resume_coordinator.gd")
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
var _latest_authoritative_event_tick: int = -1
var _last_consumed_authoritative_event_tick: int = -1
var _resume_coordinator: RefCounted = ClientRuntimeResumeCoordinatorScript.new()


func configure(peer_id: int) -> void:
	local_peer_id = peer_id


func configure_controlled_peer(peer_id: int) -> void:
	controlled_peer_id = peer_id


func start_match(config: BattleStartConfig) -> bool:
	shutdown_runtime()
	if config == null:
		return false

	start_config = config.duplicate_deep()
	controlled_peer_id = int(start_config.controlled_peer_id) if start_config != null and int(start_config.controlled_peer_id) > 0 else local_peer_id
	client_session = ClientSession.new()
	client_session.configure(local_peer_id, controlled_peer_id)
	add_child(client_session)
	snapshot_service = SnapshotService.new()
	prediction_controller = PredictionController.new()
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
	var requested_place := bool(local_input.get("action_place", false))
	var effective_place := _resolve_local_place_action(requested_place, next_tick)
	var frame := client_session.sample_input_for_tick(
		next_tick,
		clamp(int(local_input.get("move_x", 0)), -1, 1),
		clamp(int(local_input.get("move_y", 0)), -1, 1),
		effective_place
	)
	var prediction_frame: PlayerInputFrame = _build_prediction_frame(frame)
	client_session.send_input(frame, prediction_frame)
	if frame.action_place:
		_resume_coordinator.track_local_place_request(prediction_controller.predicted_sim_world if prediction_controller != null else null, frame.tick_id)
	if prediction_controller != null:
		prediction_controller.predict_to_tick(next_tick)
	return {
		"message_type": TransportMessageTypesScript.INPUT_FRAME,
		"msg_type": TransportMessageTypesScript.INPUT_FRAME,
		"protocol_version": int(start_config.protocol_version) if start_config != null else 1,
		"match_id": String(start_config.match_id) if start_config != null else "",
		"sender_peer_id": local_peer_id,
		"tick": frame.tick_id,
		"frame": frame.to_dict(),
	}


func _resolve_next_local_input_tick() -> int:
	var predicted_next_tick := prediction_controller.predicted_until_tick + 1 if prediction_controller != null else client_session.last_confirmed_tick + 1
	if start_config == null:
		return predicted_next_tick
	var lead_ticks := int(start_config.network_input_lead_ticks)
	if lead_ticks <= 0 or prediction_controller == null:
		return predicted_next_tick
	var authority_based_tick := int(prediction_controller.authoritative_tick) + lead_ticks
	return max(predicted_next_tick, authority_based_tick)


func _build_prediction_frame(frame: PlayerInputFrame) -> PlayerInputFrame:
	if frame == null:
		return null
	var prediction_frame: PlayerInputFrame = frame.duplicate_for_tick(frame.tick_id)
	if _should_suppress_action_place_prediction():
		prediction_frame.action_place = false
	return prediction_frame


func _should_suppress_action_place_prediction() -> bool:
	if start_config == null:
		return false
	return String(start_config.topology) == "dedicated_server"


func _should_suppress_authority_only_entity_prediction() -> bool:
	if start_config == null:
		return false
	return String(start_config.topology) == "dedicated_server"


func _should_compare_authority_only_entities_in_rollback() -> bool:
	return not _should_suppress_authority_only_entity_prediction()


func _should_apply_authority_sideband_to_current_world(message_tick: int) -> bool:
	return _resume_coordinator.should_apply_authority_sideband(
		prediction_controller.predicted_sim_world if prediction_controller != null else null,
		_should_suppress_authority_only_entity_prediction(),
		message_tick
	)


func ingest_network_message(message: Dictionary) -> void:
	if client_session == null:
		return
	var message_type := str(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.INPUT_ACK:
			var ack_peer_id := int(message.get("peer_id", -1))
			var expected_peer_id := controlled_peer_id if controlled_peer_id > 0 else local_peer_id
			if ack_peer_id == expected_peer_id or ack_peer_id == local_peer_id:
				client_session.on_input_ack(int(message.get("ack_tick", 0)))
		TransportMessageTypesScript.STATE_SUMMARY:
			client_session.on_state_summary(message)
			_apply_remote_player_summary_to_predicted_world(client_session.latest_player_summary)
			if _should_apply_authority_sideband_to_current_world(int(message.get("tick", 0))):
				_apply_authority_sideband_from_message(message, true, false)
			_store_authoritative_events(message)
			_inspect_pending_place_request(int(message.get("tick", 0)), "summary")
		TransportMessageTypesScript.CHECKPOINT, TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
			client_session.on_snapshot(message)
			_apply_remote_player_summary_to_predicted_world(client_session.latest_player_summary)
			if _should_apply_authority_sideband_to_current_world(int(message.get("tick", 0))):
				_apply_authority_sideband_from_message(message, true, true)
			if prediction_controller != null:
				var authoritative_snapshot := ClientRuntimeSnapshotApplierScript.snapshot_from_message(message)
				_log_snapshot_mismatch(authoritative_snapshot)
				prediction_controller.on_authoritative_snapshot(authoritative_snapshot)
			_inspect_pending_place_request(int(message.get("tick", 0)), "checkpoint")
		TransportMessageTypesScript.MATCH_FINISHED:
			_finished = true
			var result := BattleResult.from_dict(message.get("result", {}))
			var resolved_local_peer_id := controlled_peer_id if controlled_peer_id > 0 else local_peer_id
			result.bind_local_peer_context(resolved_local_peer_id)
			_apply_match_finished_to_predicted_world(result)
			battle_finished.emit(result)
		_:
			pass


func build_metrics() -> Dictionary:
	return {
		"ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"snapshot_tick": client_session.latest_snapshot_tick if client_session != null else 0,
		"predicted_tick": prediction_controller.predicted_until_tick if prediction_controller != null else 0,
		"authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else 0,
		"rollback_count": prediction_controller.rollback_controller.rollback_count if prediction_controller != null and prediction_controller.rollback_controller != null else 0,
		"resync_count": prediction_controller.rollback_controller.force_resync_count if prediction_controller != null and prediction_controller.rollback_controller != null else 0,
		"correction_count": _correction_count,
		"last_resync_tick": _last_resync_tick,
	}


func is_active() -> bool:
	return _active and not _finished


func shutdown_runtime() -> void:
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
	latest_authoritative_events.clear()
	_latest_authoritative_event_tick = -1
	_last_consumed_authoritative_event_tick = -1
	_resume_coordinator.reset()


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
	if _latest_authoritative_event_tick < 0:
		return []
	if _last_consumed_authoritative_event_tick == _latest_authoritative_event_tick:
		return []
	_last_consumed_authoritative_event_tick = _latest_authoritative_event_tick
	return latest_authoritative_events.duplicate()


func _store_authoritative_events(message: Dictionary) -> void:
	var tick_id := int(message.get("tick", 0))
	var decoded_events := ClientRuntimeSnapshotApplierScript.decode_events(message.get("events", []))
	latest_authoritative_events = decoded_events
	_latest_authoritative_event_tick = tick_id if not decoded_events.is_empty() else -1
	if decoded_events.is_empty():
		return
	_log_missing_bubble_state_after_place(tick_id, decoded_events)


func _extract_event_types(events: Array) -> Array[int]:
	var event_types: Array[int] = []
	for event in events:
		if event == null:
			continue
		event_types.append(int(event.event_type))
	return event_types


func _log_missing_bubble_state_after_place(tick_id: int, events: Array) -> void:
	if prediction_controller == null or prediction_controller.predicted_sim_world == null:
		return
	var world := prediction_controller.predicted_sim_world
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_PLACED:
			continue
		var bubble_id := int(event.payload.get("bubble_id", -1))
		if bubble_id < 0:
			LogSyncScript.warn(
				"anomaly=placed_event_missing_bubble_id tick=%d payload=%s" % [
					tick_id,
					str(event.payload),
				],
				"",
				0,
				"%s sync.client_runtime" % TRACE_TAG
			)
			continue
		var bubble = world.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			LogSyncScript.warn(
				"anomaly=placed_event_without_world_bubble tick=%d bubble_id=%d payload=%s" % [
					tick_id,
					bubble_id,
					str(event.payload),
				],
				"",
				0,
				"%s sync.client_runtime" % TRACE_TAG
			)


func _apply_authority_sideband_from_message(message: Dictionary, include_walls: bool, include_mode_state: bool) -> void:
	if prediction_controller == null or prediction_controller.predicted_sim_world == null:
		return
	var applied_tick := ClientRuntimeSnapshotApplierScript.apply_authority_sideband(
		prediction_controller.predicted_sim_world,
		message,
		include_walls,
		include_mode_state
	)
	_resume_coordinator.note_applied_authority_sideband(applied_tick)


func _resolve_local_place_action(requested_place: bool, local_tick: int) -> bool:
	return _resume_coordinator.resolve_local_place_action(
		requested_place,
		local_tick,
		prediction_controller.predicted_sim_world if prediction_controller != null else null
	)


func _inspect_pending_place_request(authoritative_tick: int, source: String) -> void:
	_resume_coordinator.inspect_pending_place_request(
		authoritative_tick,
		source,
		prediction_controller.predicted_sim_world if prediction_controller != null else null
	)


func _apply_match_finished_to_predicted_world(result: BattleResult) -> void:
	if prediction_controller == null or prediction_controller.predicted_sim_world == null or result == null:
		return
	var world := prediction_controller.predicted_sim_world
	world.state.match_state.phase = MatchState.Phase.ENDED
	world.state.match_state.winner_team_id = int(result.winner_team_ids[0]) if not result.winner_team_ids.is_empty() else -1
	world.state.match_state.winner_player_id = _resolve_winner_player_id_from_result(world, result)
	world.state.match_state.ended_reason = _finish_reason_to_match_end_reason(result.finish_reason)
	if result.finish_tick > 0:
		world.state.match_state.tick = result.finish_tick


func _resolve_winner_player_id_from_result(world: SimWorld, result: BattleResult) -> int:
	if world == null or result == null or result.winner_peer_ids.is_empty() or start_config == null:
		return -1
	var winner_peer_id := int(result.winner_peer_ids[0])
	var winner_slot := -1
	for player_entry in start_config.player_slots:
		if int(player_entry.get("peer_id", -1)) == winner_peer_id:
			winner_slot = int(player_entry.get("slot_index", -1))
			break
	if winner_slot < 0:
		return -1
	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player != null and player.player_slot == winner_slot:
			return player.entity_id
	return -1


func _finish_reason_to_match_end_reason(finish_reason: String) -> int:
	match finish_reason:
		"last_survivor":
			return MatchState.EndReason.LAST_SURVIVOR
		"team_eliminated":
			return MatchState.EndReason.TEAM_ELIMINATED
		"time_up":
			return MatchState.EndReason.TIME_UP
		"mode_objective":
			return MatchState.EndReason.MODE_OBJECTIVE
		"force_end":
			return MatchState.EndReason.FORCE_END
		_:
			return MatchState.EndReason.FORCE_END


func _apply_remote_player_summary_to_predicted_world(player_summary: Array[Dictionary]) -> void:
	if prediction_controller == null or prediction_controller.predicted_sim_world == null:
		return
	ClientRuntimeSnapshotApplierScript.apply_remote_player_summary(prediction_controller.predicted_sim_world, player_summary)


func _resolve_ignored_local_player_keys_for_rollback() -> Array[String]:
	if start_config == null:
		return []
	if String(start_config.topology) != "dedicated_server":
		return []
	return [
		"last_place_bubble_pressed",
		"bomb_available",
	]


func _log_snapshot_mismatch(authoritative_snapshot: WorldSnapshot) -> void:
	if authoritative_snapshot == null or prediction_controller == null or prediction_controller.rollback_controller == null:
		return
	var local_snapshot := prediction_controller.rollback_controller.snapshot_buffer.get_snapshot(authoritative_snapshot.tick_id)
	if local_snapshot == null:
		log_event.emit("Checkpoint mismatch tick %d: local_snapshot missing" % authoritative_snapshot.tick_id)
		return
	var rollback := prediction_controller.rollback_controller
	var reasons: Array[String] = []
	if not rollback._local_player_entries_equal(local_snapshot.players, authoritative_snapshot.players):
		reasons.append("local_player")
		var player_reason := _describe_local_player_mismatch(local_snapshot.players, authoritative_snapshot.players)
		if not player_reason.is_empty():
			reasons.append(player_reason)
	if rollback.compare_bubbles and not rollback._dictionary_array_equal(local_snapshot.bubbles, authoritative_snapshot.bubbles):
		reasons.append("bubbles")
		var bubble_reason := _describe_dictionary_array_mismatch(local_snapshot.bubbles, authoritative_snapshot.bubbles)
		if not bubble_reason.is_empty():
			reasons.append(bubble_reason)
	if rollback.compare_items and not rollback._dictionary_array_equal(local_snapshot.items, authoritative_snapshot.items):
		reasons.append("items")
		var item_reason := _describe_dictionary_array_mismatch(local_snapshot.items, authoritative_snapshot.items)
		if not item_reason.is_empty():
			reasons.append(item_reason)
	if reasons.is_empty():
		return
	if _should_suppress_rollback_probe_log(reasons):
		return
	LogSyncScript.info(
		"rollback_probe tick=%d reasons=%s predicted_until=%d ack_tick=%d local_player=%s auth_player=%s local_bubbles=%d auth_bubbles=%d local_items=%d auth_items=%d" % [
			authoritative_snapshot.tick_id,
			", ".join(reasons),
			prediction_controller.predicted_until_tick if prediction_controller != null else -1,
			client_session.last_confirmed_tick if client_session != null else -1,
			_describe_local_player_entry(local_snapshot.players),
			_describe_local_player_entry(authoritative_snapshot.players),
			local_snapshot.bubbles.size(),
			authoritative_snapshot.bubbles.size(),
			local_snapshot.items.size(),
			authoritative_snapshot.items.size(),
		],
		"",
		0,
		"%s sync.client_runtime.rollback" % TRACE_TAG
	)
	log_event.emit("Checkpoint mismatch tick %d: %s" % [authoritative_snapshot.tick_id, ", ".join(reasons)])


func _should_suppress_rollback_probe_log(reasons: Array[String]) -> bool:
	if reasons.is_empty():
		return true
	if reasons.has("bubbles") or reasons.has("items"):
		return false
	for reason in reasons:
		if not reason.begins_with("key "):
			continue
		if reason.begins_with("key move_phase_ticks "):
			return true
	return false


func _describe_dictionary_array_mismatch(local_values: Array[Dictionary], authoritative_values: Array[Dictionary]) -> String:
	if local_values.size() != authoritative_values.size():
		return "size %d!=%d" % [local_values.size(), authoritative_values.size()]
	var rollback := prediction_controller.rollback_controller if prediction_controller != null else null
	for index in range(local_values.size()):
		var local_entry := local_values[index]
		var authoritative_entry := authoritative_values[index]
		if rollback != null and rollback._dictionary_equal(local_entry, authoritative_entry):
			continue
		for key in authoritative_entry.keys():
			if rollback != null and rollback._variant_equal(local_entry.get(key), authoritative_entry.get(key)):
				continue
			return "idx %d key %s local=%s auth=%s" % [index, str(key), str(local_entry.get(key)), str(authoritative_entry.get(key))]
		var local_only_keys: Array[String] = []
		for key in local_entry.keys():
			if authoritative_entry.has(key):
				continue
			local_only_keys.append(str(key))
		if not local_only_keys.is_empty():
			return "idx %d local_only_keys=%s local=%s auth=%s" % [index, str(local_only_keys), str(local_entry), str(authoritative_entry)]
		return "idx %d entry differs local=%s auth=%s" % [index, str(local_entry), str(authoritative_entry)]
	return "content differs"


func _describe_local_player_mismatch(local_values: Array[Dictionary], authoritative_values: Array[Dictionary]) -> String:
	var rollback := prediction_controller.rollback_controller if prediction_controller != null else null
	if rollback == null:
		return ""
	var local_entry := rollback._find_local_player_entry(local_values)
	var authoritative_entry := rollback._find_local_player_entry(authoritative_values)
	if local_entry.is_empty() or authoritative_entry.is_empty():
		return "missing local controlled player entry"
	if rollback._dictionary_equal(local_entry, authoritative_entry):
		return ""
	for key in authoritative_entry.keys():
		if rollback.ignored_local_player_keys.has(str(key)):
			continue
		if rollback._variant_equal(local_entry.get(key), authoritative_entry.get(key)):
			continue
		return "key %s local=%s auth=%s" % [str(key), str(local_entry.get(key)), str(authoritative_entry.get(key))]
	return "entry differs"


func _describe_local_player_entry(values: Array[Dictionary]) -> String:
	var rollback := prediction_controller.rollback_controller if prediction_controller != null else null
	if rollback == null:
		return "{}"
	var entry := rollback._find_local_player_entry(values)
	return str(entry)


func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	_correction_count += 1
	LogSyncScript.info(
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
	LogSyncScript.info(
		"rollback_resync tick=%d rollback_count=%d resync_count=%d" % [
			_last_resync_tick,
			prediction_controller.rollback_controller.rollback_count if prediction_controller != null and prediction_controller.rollback_controller != null else -1,
			prediction_controller.rollback_controller.force_resync_count if prediction_controller != null and prediction_controller.rollback_controller != null else -1,
		],
		"",
		0,
		"%s sync.client_runtime.rollback" % TRACE_TAG
	)
	prediction_event.emit({
		"type": "full_resync",
		"tick": _last_resync_tick,
		"message": "Client full resync at tick %d" % _last_resync_tick,
	})
