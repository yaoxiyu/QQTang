class_name ServerSession
extends Node

const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const TRACE_TAG := "sync.trace"
const DEBUG_SYNC_EVENT_LOGS := false

var room_session: RoomSession = RoomSession.new()
var active_match: BattleMatch = null
var outgoing_messages: Array[Dictionary] = []


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
		"msg_type": "MATCH_START",
		"match_id": active_match.match_id,
		"start_tick": start_tick,
		"seed": _seed,
		"peer_ids": active_match.peer_ids
	})
	return true


func receive_input(frame: PlayerInputFrame) -> void:
	if active_match == null:
		return
	active_match.push_player_input(frame)


func tick_once() -> void:
	if active_match == null:
		return

	var next_tick := active_match.sim_world.state.match_state.tick + 1
	_tick_collect_inputs(next_tick)
	_tick_world(next_tick)
	_tick_snapshot(next_tick)
	_tick_ack_inputs(next_tick)


func poll_messages() -> Array[Dictionary]:
	var messages := outgoing_messages.duplicate(true)
	outgoing_messages.clear()
	return messages


func _tick_collect_inputs(_tick_id: int) -> void:
	if active_match == null:
		return


func _tick_world(_tick_id: int) -> void:
	if active_match == null:
		return

	var result := active_match.run_authoritative_tick()
	if result.is_empty():
		return

	var tick_id := int(result.get("tick", 0))
	var snapshot: WorldSnapshot = active_match.borrow_last_authoritative_snapshot()
	if snapshot == null or snapshot.tick_id != tick_id:
		snapshot = active_match.get_snapshot(tick_id)
	var events: Array = _serialize_events(result.get("events", []))
	_log_bubble_placed_events(tick_id, events, snapshot)
	_queue_message({
		"msg_type": "STATE_SUMMARY",
		"tick": tick_id,
		"player_summary": active_match.build_player_position_summary(),
		"bubbles": snapshot.bubbles if snapshot != null else [],
		"items": snapshot.items if snapshot != null else [],
		"match_state": snapshot.match_state.duplicate(true) if snapshot != null else {},
		"events": events,
		"checksum": snapshot.checksum if snapshot != null else 0
	})

func _tick_snapshot(tick_id: int) -> void:
	if active_match == null or tick_id % 5 != 0:
		return

	var snapshot := active_match.borrow_last_authoritative_snapshot()
	if snapshot == null or snapshot.tick_id != tick_id:
		snapshot = active_match.get_snapshot(tick_id)
	if snapshot == null:
		snapshot = active_match.snapshot_service.build_standard_snapshot(active_match.sim_world, tick_id, false)
		snapshot.checksum = active_match.compute_checksum(tick_id)

	_queue_message({
		"msg_type": "CHECKPOINT",
		"tick": snapshot.tick_id,
		"players": snapshot.players,
		"player_summary": active_match.build_player_position_summary(),
		"bubbles": snapshot.bubbles,
		"items": snapshot.items,
		"walls": snapshot.walls,
		"match_state": snapshot.match_state.duplicate(true),
		"mode_state": snapshot.mode_state.duplicate(true),
		"rng_state": snapshot.rng_state,
		"checksum": snapshot.checksum
	})


func _tick_ack_inputs(tick_id: int) -> void:
	if active_match == null:
		return

	for peer_id in active_match.peer_ids:
		_queue_message({
			"msg_type": "INPUT_ACK",
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
	if active_match != null:
		active_match.dispose()
		active_match = null
