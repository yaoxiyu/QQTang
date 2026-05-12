class_name ClientAuthorityIngestion
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ClientRuntimeSnapshotApplierScript = preload("res://network/session/runtime/client_runtime_snapshot_applier.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const RollbackTelemetryScript = preload("res://network/session/runtime/rollback_telemetry.gd")

const TRACE_TAG := "sync.trace"

var _runtime: Node = null
var _last_authority_batch_metrics: Dictionary = {}
var _latest_authoritative_event_tick: int = -1
var _last_consumed_authoritative_event_tick: int = -1


func configure(runtime: Node) -> void:
	_runtime = runtime


func ingest_network_message(message: Dictionary) -> void:
	if _runtime == null or _runtime.client_session == null:
		return
	var message_type := str(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.INPUT_ACK:
			_apply_batch_input_acks([message])
		TransportMessageTypesScript.INPUT_ACK_BATCH:
			_apply_ack_by_peer(message.get("ack_by_peer", {}))
		TransportMessageTypesScript.STATE_SUMMARY:
			_apply_latest_state_summary(message)
			_store_authoritative_events(message)
			_inspect_pending_place_request(int(message.get("tick", 0)), "summary")
		TransportMessageTypesScript.STATE_DELTA:
			_apply_latest_state_delta(message)
			_store_authoritative_events(message)
			_inspect_pending_place_request(int(message.get("tick", 0)), "delta")
		TransportMessageTypesScript.CHECKPOINT, TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
			_apply_latest_authoritative_snapshot(message)
			_inspect_pending_place_request(int(message.get("tick", 0)), "checkpoint")
		TransportMessageTypesScript.MATCH_FINISHED:
			_apply_terminal_message(message)
		_:
			pass


func ingest_authority_batch(batch: Dictionary) -> void:
	if _runtime == null or _runtime.client_session == null or batch.is_empty():
		return
	_apply_batch_input_acks(batch.get("input_acks", []))
	_apply_latest_state_summary(batch.get("latest_state_summary", {}))
	_apply_latest_state_delta(batch.get("latest_state_delta", {}))
	_store_authoritative_events_by_tick(batch.get("authority_events_by_tick", []))
	_apply_latest_authoritative_snapshot(batch.get("latest_snapshot_message", {}))
	_apply_terminal_messages(batch.get("terminal_messages", []))
	var raw_metrics = batch.get("metrics", {})
	_last_authority_batch_metrics = raw_metrics.duplicate(true) if raw_metrics is Dictionary else {}


func consume_pending_authoritative_events() -> Array:
	if _runtime == null or _runtime.pending_authoritative_events_by_tick.is_empty():
		return []
	var ticks: Array = _runtime.pending_authoritative_events_by_tick.keys()
	ticks.sort()
	var consumed_events: Array = []
	var max_consumed_tick := _last_consumed_authoritative_event_tick
	for tick_value in ticks:
		var tick_id := int(tick_value)
		if tick_id <= _last_consumed_authoritative_event_tick:
			continue
		consumed_events.append_array((_runtime.pending_authoritative_events_by_tick[tick_value] as Array).duplicate())
		max_consumed_tick = max(max_consumed_tick, tick_id)
	if consumed_events.is_empty():
		return []
	_last_consumed_authoritative_event_tick = max_consumed_tick
	_runtime.latest_authoritative_events = consumed_events.duplicate()
	_latest_authoritative_event_tick = max_consumed_tick
	return consumed_events


func get_last_authority_batch_metrics() -> Dictionary:
	return _last_authority_batch_metrics.duplicate(true)


func get_last_consumed_event_tick() -> int:
	return _last_consumed_authoritative_event_tick


func reset() -> void:
	_last_authority_batch_metrics.clear()
	_latest_authoritative_event_tick = -1
	_last_consumed_authoritative_event_tick = -1


func _store_authoritative_events(message: Dictionary) -> void:
	var tick_id := int(message.get("tick", 0))
	var decoded_events := ClientRuntimeSnapshotApplierScript.decode_events(_event_payloads_from_message(message))
	_runtime.latest_authoritative_events = decoded_events
	_latest_authoritative_event_tick = tick_id if not decoded_events.is_empty() else -1
	if decoded_events.is_empty():
		return
	_runtime.pending_authoritative_events_by_tick[tick_id] = decoded_events
	_log_explosion_events("client_ingest", tick_id, decoded_events, message)
	_log_missing_bubble_state_after_place(tick_id, decoded_events)


func _store_authoritative_events_by_tick(entries: Array) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var tick_id := int((entry as Dictionary).get("tick", -1))
		if tick_id < 0:
			continue
		var decoded_events := ClientRuntimeSnapshotApplierScript.decode_events(_event_payloads_from_message(entry as Dictionary))
		if decoded_events.is_empty():
			continue
		if not _runtime.pending_authoritative_events_by_tick.has(tick_id):
			_runtime.pending_authoritative_events_by_tick[tick_id] = []
		(_runtime.pending_authoritative_events_by_tick[tick_id] as Array).append_array(decoded_events)
		_runtime.latest_authoritative_events = decoded_events
		_latest_authoritative_event_tick = max(_latest_authoritative_event_tick, tick_id)
		_log_explosion_events("client_ingest_batch", tick_id, decoded_events, entry as Dictionary)
		_log_missing_bubble_state_after_place(tick_id, decoded_events)


func _event_payloads_from_message(message: Dictionary) -> Array:
	var events: Variant = message.get("events", [])
	if events is Array and not events.is_empty():
		return events
	var event_details: Variant = message.get("event_details", [])
	if event_details is Array:
		return event_details
	return []


func _log_explosion_events(stage: String, tick_id: int, events: Array, source_message: Dictionary) -> void:
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_EXPLODED:
			continue
		var covered_cells: Array = event.payload.get("covered_cells", [])
		LogSyncScript.info(
			"QQT_EXPLOSION_TRACE stage=%s tick=%d event_tick=%d msg_type=%s bubble_id=%d owner=%d cell=(%d,%d) covered_cells=%d payload_keys=%s" % [
				stage,
				tick_id,
				int(event.tick),
				String(source_message.get("message_type", source_message.get("msg_type", ""))),
				int(event.payload.get("bubble_id", event.payload.get("entity_id", -1))),
				int(event.payload.get("owner_player_id", -1)),
				int(event.payload.get("cell_x", -1)),
				int(event.payload.get("cell_y", -1)),
				covered_cells.size(),
				str(event.payload.keys()),
			],
			"",
			0,
			"%s sync.client_authority_ingestion" % TRACE_TAG
		)


func _apply_batch_input_acks(input_acks: Array) -> void:
	if _runtime.client_session == null:
		return
	var expected_peer_id: int = _runtime.controlled_peer_id if _runtime.controlled_peer_id > 0 else _runtime.local_peer_id
	for ack in input_acks:
		if not (ack is Dictionary):
			continue
		var ack_peer_id := int((ack as Dictionary).get("peer_id", -1))
		if ack_peer_id == expected_peer_id or ack_peer_id == _runtime.local_peer_id:
			_runtime.client_session.on_input_ack(int((ack as Dictionary).get("ack_tick", 0)))


func _apply_ack_by_peer(ack_by_peer: Variant) -> void:
	if _runtime.client_session == null or not (ack_by_peer is Dictionary):
		return
	var expected_peer_id: int = _runtime.controlled_peer_id if _runtime.controlled_peer_id > 0 else _runtime.local_peer_id
	var fallback_ack_tick := -1
	for key in (ack_by_peer as Dictionary).keys():
		var peer_id := int(key)
		var ack_tick := int((ack_by_peer as Dictionary).get(key, 0))
		fallback_ack_tick = max(fallback_ack_tick, ack_tick)
		if peer_id == expected_peer_id or peer_id == _runtime.local_peer_id:
			_runtime.client_session.on_input_ack(ack_tick)
			return
	if fallback_ack_tick >= 0:
		_runtime.client_session.on_input_ack(fallback_ack_tick)


func _apply_latest_state_summary(message: Dictionary) -> void:
	if _runtime.client_session == null or message.is_empty():
		return
	_apply_ack_by_peer(message.get("ack_by_peer", {}))
	if _runtime._finished:
		return
	_runtime.client_session.on_state_summary(message)
	_apply_remote_player_summary_to_predicted_world(_runtime.client_session.latest_player_summary)
	if _runtime._should_apply_authority_sideband_to_current_world(int(message.get("tick", 0))):
		_apply_authority_sideband_from_message(message, false, false)


func _apply_latest_state_delta(message: Dictionary) -> void:
	if _runtime.client_session == null or message.is_empty():
		return
	if _runtime._finished:
		return
	if _runtime._should_apply_authority_sideband_to_current_world(int(message.get("tick", 0))):
		ClientRuntimeSnapshotApplierScript.apply_authority_delta_sideband(
			_runtime.prediction_controller.predicted_sim_world if _runtime.prediction_controller != null else null,
			message
		)
		_runtime._resume_coordinator.note_applied_authority_sideband(int(message.get("tick", 0)))


func _apply_latest_authoritative_snapshot(message: Dictionary) -> void:
	if _runtime.client_session == null or message.is_empty():
		return
	if _runtime._finished:
		return
	_runtime.client_session.on_snapshot(message)
	_apply_remote_player_summary_to_predicted_world(_runtime.client_session.latest_player_summary)
	if _runtime._should_apply_authority_sideband_to_current_world(int(message.get("tick", 0))):
		_apply_authority_sideband_from_message(message, true, true)
	if _runtime.prediction_controller != null:
		var authoritative_snapshot := ClientRuntimeSnapshotApplierScript.snapshot_from_message(message)
		_log_snapshot_mismatch(authoritative_snapshot)
		_runtime.prediction_controller.on_authoritative_snapshot(authoritative_snapshot)


func _apply_terminal_messages(messages: Array) -> void:
	for message in messages:
		if message is Dictionary:
			_apply_terminal_message(message)


func _apply_terminal_message(message: Dictionary) -> void:
	if message.is_empty():
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type != TransportMessageTypesScript.MATCH_FINISHED:
		return
	_runtime._finished = true
	var result := BattleResult.from_dict(message.get("result", {}))
	var resolved_local_peer_id: int = _runtime.controlled_peer_id if _runtime.controlled_peer_id > 0 else _runtime.local_peer_id
	result.bind_local_peer_context(resolved_local_peer_id)
	_apply_match_finished_to_predicted_world(result)
	_runtime.battle_finished.emit(result)


func _log_missing_bubble_state_after_place(tick_id: int, events: Array) -> void:
	if _runtime.prediction_controller == null or _runtime.prediction_controller.predicted_sim_world == null:
		return
	var world: SimWorld = _runtime.prediction_controller.predicted_sim_world
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_PLACED:
			continue
		var bubble_id := int(event.payload.get("bubble_id", -1))
		if bubble_id < 0:
			LogSyncScript.warn(
				"anomaly=placed_event_missing_bubble_id tick=%d payload=%s" % [tick_id, str(event.payload)],
				"",
				0,
				"%s sync.client_authority_ingestion" % TRACE_TAG
			)
			continue
		var bubble = world.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			# The bubble is queued in pending_authoritative_events_by_tick
			# and will be spawned when the prediction loop replays this
			# tick (this is the normal path when local placement was
			# rejected or the bubble belongs to another peer). Log at
			# DEBUG so the trace stays available without flooding WARN.
			LogSyncScript.debug(
				"placed_event_pending_apply tick=%d bubble_id=%d" % [tick_id, bubble_id],
				"",
				0,
				"%s sync.client_authority_ingestion" % TRACE_TAG
			)


func _apply_authority_sideband_from_message(message: Dictionary, include_walls: bool, include_mode_state: bool) -> void:
	if _runtime.prediction_controller == null or _runtime.prediction_controller.predicted_sim_world == null:
		return
	var applied_tick := ClientRuntimeSnapshotApplierScript.apply_authority_sideband(
		_runtime.prediction_controller.predicted_sim_world,
		message,
		include_walls,
		include_mode_state
	)
	_runtime._resume_coordinator.note_applied_authority_sideband(applied_tick)


func _inspect_pending_place_request(authoritative_tick: int, source: String) -> void:
	_runtime._resume_coordinator.inspect_pending_place_request(
		authoritative_tick,
		source,
		_runtime.prediction_controller.predicted_sim_world if _runtime.prediction_controller != null else null
	)


func _apply_match_finished_to_predicted_world(result: BattleResult) -> void:
	if _runtime.prediction_controller == null or _runtime.prediction_controller.predicted_sim_world == null or result == null:
		return
	var world: SimWorld = _runtime.prediction_controller.predicted_sim_world
	world.state.match_state.phase = MatchState.Phase.ENDED
	world.state.match_state.winner_team_id = int(result.winner_team_ids[0]) if not result.winner_team_ids.is_empty() else -1
	world.state.match_state.winner_player_id = _resolve_winner_player_id_from_result(world, result)
	world.state.match_state.ended_reason = _finish_reason_to_match_end_reason(result.finish_reason)
	if result.finish_tick > 0:
		world.state.match_state.tick = result.finish_tick


func _resolve_winner_player_id_from_result(world: SimWorld, result: BattleResult) -> int:
	if world == null or result == null or result.winner_peer_ids.is_empty() or _runtime.start_config == null:
		return -1
	var winner_peer_id := int(result.winner_peer_ids[0])
	var winner_slot := -1
	for player_entry in _runtime.start_config.player_slots:
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
	if _runtime.prediction_controller == null or _runtime.prediction_controller.predicted_sim_world == null:
		return
	ClientRuntimeSnapshotApplierScript.apply_remote_player_summary(_runtime.prediction_controller.predicted_sim_world, player_summary)


func _log_snapshot_mismatch(authoritative_snapshot: WorldSnapshot) -> void:
	if authoritative_snapshot == null or _runtime.prediction_controller == null or _runtime.prediction_controller.rollback_controller == null:
		return
	var local_snapshot: WorldSnapshot = _runtime.prediction_controller.rollback_controller.snapshot_buffer.get_snapshot(authoritative_snapshot.tick_id)
	if local_snapshot == null:
		_runtime.log_event.emit("Checkpoint mismatch tick %d: local_snapshot missing" % authoritative_snapshot.tick_id)
		return
	var rollback: RollbackController = _runtime.prediction_controller.rollback_controller
	var reasons: Array[String] = []
	var diff: Dictionary = rollback.describe_snapshot_diff(local_snapshot, authoritative_snapshot)
	if bool(diff.get("equal", false)):
		return
	var section := String(diff.get("first_diff_section", ""))
	if not section.is_empty():
		reasons.append(section)
	var field := String(diff.get("first_diff_field", ""))
	if not field.is_empty():
		reasons.append("key %s local=%s auth=%s" % [
			field,
			str(diff.get("local_value", null)),
			str(diff.get("authority_value", null)),
		])
	if reasons.is_empty() or _should_suppress_rollback_probe_log(reasons):
		return
	RollbackTelemetryScript.shared().record_probe(
		reasons,
		_runtime.prediction_controller.predicted_until_tick if _runtime.prediction_controller != null else -1,
		_runtime.client_session.last_confirmed_tick if _runtime.client_session != null else -1
	)
	RollbackTelemetryScript.shared().flush_if_due()
	LogSyncScript.debug(
		"rollback_probe tick=%d reasons=%s predicted_until=%d ack_tick=%d local_player=%s auth_player=%s local_bubbles=%d auth_bubbles=%d local_items=%d auth_items=%d" % [
			authoritative_snapshot.tick_id,
			", ".join(reasons),
			_runtime.prediction_controller.predicted_until_tick if _runtime.prediction_controller != null else -1,
			_runtime.client_session.last_confirmed_tick if _runtime.client_session != null else -1,
			_find_player_entry_for_log(local_snapshot.players),
			_find_player_entry_for_log(authoritative_snapshot.players),
			local_snapshot.bubbles.size(),
			authoritative_snapshot.bubbles.size(),
			local_snapshot.items.size(),
			authoritative_snapshot.items.size(),
		],
		"",
		0,
		"%s sync.client_authority_ingestion.rollback" % TRACE_TAG
	)
	_runtime.log_event.emit("Checkpoint mismatch tick %d: %s" % [authoritative_snapshot.tick_id, ", ".join(reasons)])


func _should_suppress_rollback_probe_log(reasons: Array[String]) -> bool:
	if reasons.is_empty():
		return true
	if reasons.has("bubbles") or reasons.has("items"):
		return false
	for reason in reasons:
		if not reason.begins_with("key "):
			continue
		if reason.begins_with("key move_remainder_units "):
			return true
	return false


func _find_player_entry_for_log(values: Array[Dictionary]) -> String:
	var target_slot: int = _runtime._resolve_controlled_slot(_runtime.start_config)
	for entry in values:
		if int(entry.get("player_slot", -1)) == target_slot:
			return str(entry)
	return "{}"
