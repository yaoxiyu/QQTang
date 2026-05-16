class_name ServerSession
extends Node

const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const AuthorityStateSummaryBuilderScript = preload("res://network/session/runtime/authority_state_summary_builder.gd")
const AuthorityStateDeltaBuilderScript = preload("res://network/session/runtime/authority_state_delta_builder.gd")
const AuthorityCheckpointBuilderScript = preload("res://network/session/runtime/authority_checkpoint_builder.gd")
const RuntimeShutdownContextScript = preload("res://app/runtime/runtime_shutdown_context.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const TRACE_TAG := "sync.trace"
const DEBUG_SYNC_EVENT_LOGS := false

var room_session: RoomSession = RoomSession.new()
var active_match: BattleMatch = null
var outgoing_messages: Array[Dictionary] = []
var _state_summary_builder: RefCounted = AuthorityStateSummaryBuilderScript.new()
var _state_delta_builder: RefCounted = AuthorityStateDeltaBuilderScript.new()
var _checkpoint_builder: RefCounted = AuthorityCheckpointBuilderScript.new()
var _last_tick_snapshot: WorldSnapshot = null
var _checkpoint_interval_ticks: int = 5
const CHECKPOINT_FALLBACK_WINDOW_TICKS: int = 60
var _last_fallback_idle_count: int = 0
var _fallback_event_ticks: Array[int] = []


func create_room(room_id: String, map_id: String = "", mode_id: String = "") -> void:
	room_session = RoomSession.new(room_id)
	room_session.set_selection(map_id, "", mode_id)


func add_peer(peer_id: int) -> void:
	room_session.add_peer(peer_id)


func set_peer_ready(peer_id: int, _ready: bool) -> void:
	room_session.set_ready(peer_id, _ready)


func start_match(config: SimConfig, bootstrap_data: Dictionary = {}, _seed: int = 1, start_tick: int = 0) -> bool:
	if not room_session.can_start():
		return false

	room_session.lock_config()
	active_match = BattleMatch.new()
	active_match.configure_from_room(room_session, _make_match_id(), _seed, start_tick)
	active_match.bootstrap_world(config, bootstrap_data)

	_queue_message({
		"message_type": "MATCH_START",
		"match_id": active_match.match_id,
		"start_tick": start_tick,
		"seed": _seed,
		"peer_ids": active_match.peer_ids
	})
	return true


func receive_input(frame: PlayerInputFrame, authority_tick: int = -1) -> Dictionary:
	if active_match == null:
		return {"status": "drop_no_active_match"}
	return active_match.push_player_input(frame, authority_tick)


func tick_once() -> void:
	if active_match == null:
		return

	var next_tick := active_match.sim_world.state.match_state.tick + 1
	_tick_world(next_tick)
	_tick_snapshot(next_tick)
	_tick_ack_inputs(next_tick)


func poll_messages() -> Array[Dictionary]:
	var messages := outgoing_messages.duplicate(true)
	outgoing_messages.clear()
	return messages


func build_wire_budget_metrics() -> Dictionary:
	return {
		"state_summary": _state_summary_builder.build_metrics() if _state_summary_builder != null else {},
		"state_delta": _state_delta_builder.build_metrics() if _state_delta_builder != null else {},
		"checkpoint": _checkpoint_builder.build_metrics() if _checkpoint_builder != null else {},
	}


func _tick_world(_tick_id: int) -> void:
	if active_match == null:
		return

	var result := active_match.run_authoritative_tick()
	if result.is_empty():
		return

	var tick_id := int(result.get("tick", 0))
	var snapshot: WorldSnapshot = result.get("authoritative_snapshot", null)
	if snapshot == null:
		snapshot = active_match.borrow_last_authoritative_snapshot()
		if snapshot == null or snapshot.tick_id != tick_id:
			snapshot = active_match.get_snapshot(tick_id)
	_last_tick_snapshot = snapshot
	var events: Array = _serialize_events(result.get("events", []))
	_log_bubble_placed_events(tick_id, events, snapshot)
	_log_explosion_events(tick_id, events)
	_queue_message(_state_summary_builder.build_core(active_match, snapshot, tick_id, events))
	var delta: Dictionary = _state_delta_builder.build_delta(active_match, snapshot, tick_id, events)
	if not delta.is_empty():
		_queue_message(delta)

func _tick_snapshot(tick_id: int) -> void:
	if active_match == null:
		return
	var checkpoint_interval := _resolve_checkpoint_interval_ticks()
	if checkpoint_interval <= 0 or tick_id % checkpoint_interval != 0:
		return

	var snapshot := _last_tick_snapshot
	if snapshot == null or snapshot.tick_id != tick_id:
		snapshot = active_match.borrow_last_authoritative_snapshot()
	if snapshot == null or snapshot.tick_id != tick_id:
		snapshot = active_match.get_snapshot(tick_id)
	if snapshot == null:
		snapshot = active_match.snapshot_service.build_standard_snapshot(active_match.sim_world, tick_id, false)
		snapshot.checksum = active_match.compute_checksum(tick_id)

	_queue_message(_checkpoint_builder.build_checkpoint(active_match, snapshot))


func _resolve_checkpoint_interval_ticks() -> int:
	if active_match == null or active_match.input_buffer == null:
		return _checkpoint_interval_ticks
	var current_tick: int = active_match.sim_world.state.match_state.tick
	var metrics: Dictionary = active_match.input_buffer.get_native_metrics()
	var current_idle_count: int = int(metrics.get("fallback_idle_count", 0))

	# Detect new fallback events since last check and record their tick
	if current_idle_count > _last_fallback_idle_count:
		_fallback_event_ticks.append(current_tick)
		_last_fallback_idle_count = current_idle_count

	# Prune events outside the sliding window
	var cutoff := current_tick - CHECKPOINT_FALLBACK_WINDOW_TICKS
	while not _fallback_event_ticks.is_empty() and _fallback_event_ticks[0] <= cutoff:
		_fallback_event_ticks.pop_front()

	if not _fallback_event_ticks.is_empty():
		return 3
	return _checkpoint_interval_ticks


func _tick_ack_inputs(tick_id: int) -> void:
	if active_match == null:
		return

	for peer_id in active_match.peer_ids:
		_queue_message({
			"message_type": "INPUT_ACK",
			"peer_id": peer_id,
			"ack_tick": tick_id
		})
		active_match.input_buffer.ack_peer(peer_id, tick_id)


func _queue_message(message: Dictionary) -> void:
	outgoing_messages.append(message)


func _make_match_id() -> String:
	return "%s_%d" % [room_session.room_id, Time.get_ticks_msec()]


func _serialize_events(raw_events: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_event in raw_events:
		if raw_event == null:
			continue
		serialized.append({
			"tick": int(raw_event.tick),
			"event_type": int(raw_event.event_type),
			"payload": _normalize_variant(raw_event.payload),
		})
	return serialized


func _log_bubble_placed_events(tick_id: int, events: Array[Dictionary], snapshot: WorldSnapshot) -> void:
	if not DEBUG_SYNC_EVENT_LOGS:
		return
	for event in events:
		if int(event.get("event_type", -1)) != SimEventScript.EventType.BUBBLE_PLACED:
			continue
		var payload: Dictionary = event.get("payload", {})
		LogSyncScript.info(
			"authority_bubble_placed tick=%d bubble_id=%d owner=%d cell=(%d,%d) snapshot_bubbles=%d" % [
				tick_id,
				int(payload.get("bubble_id", -1)),
				int(payload.get("owner_player_id", -1)),
				int(payload.get("cell_x", -1)),
				int(payload.get("cell_y", -1)),
				snapshot.bubbles.size() if snapshot != null else -1,
			],
			"",
			0,
			"%s sync.server_session" % TRACE_TAG
		)


func _log_explosion_events(tick_id: int, events: Array) -> void:
	for event in events:
		if not (event is Dictionary):
			continue
		if int((event as Dictionary).get("event_type", -1)) != SimEventScript.EventType.BUBBLE_EXPLODED:
			continue
		var payload: Dictionary = (event as Dictionary).get("payload", {})
		var covered_cells: Array = payload.get("covered_cells", [])
		LogSyncScript.info(
			"QQT_EXPLOSION_TRACE stage=server_event tick=%d event_tick=%d bubble_id=%d owner=%d cell=(%d,%d) covered_cells=%d payload_keys=%s" % [
				tick_id,
				int((event as Dictionary).get("tick", -1)),
				int(payload.get("bubble_id", payload.get("entity_id", -1))),
				int(payload.get("owner_player_id", -1)),
				int(payload.get("cell_x", -1)),
				int(payload.get("cell_y", -1)),
				covered_cells.size(),
				str(payload.keys()),
			],
			"",
			0,
			"%s sync.server_session" % TRACE_TAG
		)


func _normalize_variant(value: Variant) -> Variant:
	if value is Vector2i:
		return {"x": value.x, "y": value.y, "__type": "Vector2i"}
	if value is Vector2:
		return {"x": value.x, "y": value.y, "__type": "Vector2"}
	if value is Dictionary:
		var normalized: Dictionary = {}
		for key in value.keys():
			normalized[key] = _normalize_variant(value[key])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for entry in value:
			normalized_array.append(_normalize_variant(entry))
		return normalized_array
	return value


func _exit_tree() -> void:
	shutdown_runtime()


func shutdown_runtime() -> void:
	shutdown(RuntimeShutdownContextScript.new("server_session_shutdown", false))


func get_shutdown_name() -> String:
	return "server_session"


func get_shutdown_priority() -> int:
	return 60


func shutdown(_context: Variant) -> void:
	if active_match != null:
		active_match.dispose()
		active_match = null
	outgoing_messages.clear()
	_last_tick_snapshot = null
	_last_fallback_idle_count = 0
	_fallback_event_ticks.clear()
	_state_summary_builder.reset()
	_state_delta_builder.reset()
	_checkpoint_builder.reset()


func get_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"has_active_match": active_match != null,
		"pending_outgoing_messages": outgoing_messages.size(),
	}
