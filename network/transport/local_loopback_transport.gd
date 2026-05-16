class_name LocalLoopbackTransport
extends IBattleTransport

const TransportMessageCodecScript = preload("res://network/transport/transport_message_codec.gd")
const TransportDebugSimulatorScript = preload("res://network/transport/transport_debug_simulator.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

const DEFAULT_DROPPABLE_MESSAGE_TYPES: Array[String] = [
	TransportMessageTypesScript.INPUT_ACK,
	TransportMessageTypesScript.STATE_SUMMARY,
	TransportMessageTypesScript.STATE_DELTA,
	TransportMessageTypesScript.CHECKPOINT,
]

var _connected: bool = false
var _server_mode: bool = false
var _local_peer_id: int = 0
var _remote_peer_ids: Array[int] = []
var _incoming_queue: Array[Dictionary] = []
var _pending_entries: Array[Dictionary] = []
var _current_tick: int = 0
var _droppable_message_types: Array[String] = DEFAULT_DROPPABLE_MESSAGE_TYPES.duplicate()
var _debug_simulator: TransportDebugSimulator = TransportDebugSimulatorScript.new()


func initialize(config: Dictionary = {}) -> void:
	shutdown()
	_server_mode = bool(config.get("is_server", false))
	_local_peer_id = int(config.get("local_peer_id", 0))
	_remote_peer_ids.clear()
	for peer_id in config.get("remote_peer_ids", []):
		_remote_peer_ids.append(int(peer_id))
	_current_tick = int(config.get("current_tick", 0))
	var _rng_seed: int = int(config.get("seed", 0))
	_debug_simulator.configure(_rng_seed)
	_debug_simulator.reset_stats()
	if config.has("droppable_message_types"):
		_droppable_message_types.clear()
		for message_type in config.get("droppable_message_types", []):
			_droppable_message_types.append(str(message_type))
	else:
		_droppable_message_types = DEFAULT_DROPPABLE_MESSAGE_TYPES.duplicate()
	if config.has("debug_profile"):
		apply_debug_profile(config.get("debug_profile", {}))
	_connected = true
	connected.emit()

func shutdown() -> void:
	if _connected:
		disconnected.emit()
	_connected = false
	_incoming_queue.clear()
	_pending_entries.clear()
	_current_tick = 0
	_remote_peer_ids.clear()
	_debug_simulator.reset_stats()


func poll() -> void:
	if not _connected:
		return
	var deliverable: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for entry in _pending_entries:
		if int(entry.get("deliver_tick", 0)) <= _current_tick:
			deliverable.append(entry.get("message", {}))
			_debug_simulator.record_delivered()
		else:
			pending.append(entry)
	_pending_entries = pending
	_incoming_queue.append_array(deliverable)


func is_server() -> bool:
	return _server_mode


func is_transport_connected() -> bool:
	return _connected


func get_local_peer_id() -> int:
	return _local_peer_id


func get_remote_peer_ids() -> Array[int]:
	return _remote_peer_ids.duplicate()


func send_to_peer(_peer_id: int, message: Dictionary) -> void:
	_enqueue_message(message)


func broadcast(message: Dictionary) -> void:
	if _remote_peer_ids.is_empty():
		_enqueue_message(message)
		return
	for _peer_id in _remote_peer_ids:
		_enqueue_message(message)


func consume_incoming() -> Array[Dictionary]:
	var messages := _incoming_queue.duplicate(true)
	_incoming_queue.clear()
	return messages


func set_current_tick(tick_id: int) -> void:
	_current_tick = tick_id


func cycle_latency_profile() -> int:
	return _debug_simulator.cycle_latency_profile()


func cycle_loss_profile() -> int:
	return _debug_simulator.cycle_loss_profile()


func get_latency_profile_ms() -> int:
	return _debug_simulator.get_latency_profile_ms()


func get_packet_loss_percent() -> int:
	return _debug_simulator.get_packet_loss_percent()


func get_network_profile_summary() -> String:
	return _debug_simulator.get_network_profile_summary()


func get_debug_stats() -> Dictionary:
	return _debug_simulator.get_stats()


func get_pending_message_count() -> int:
	return _pending_entries.size()


func export_debug_profile() -> Dictionary:
	return {
		"latency_profile_index": _debug_simulator.latency_profile_index,
		"loss_profile_index": _debug_simulator.loss_profile_index,
	}


func apply_debug_profile(profile: Dictionary) -> void:
	_debug_simulator.latency_profile_index = int(profile.get("latency_profile_index", _debug_simulator.latency_profile_index)) % TransportDebugSimulatorScript.LATENCY_PROFILES_MS.size()
	_debug_simulator.loss_profile_index = int(profile.get("loss_profile_index", _debug_simulator.loss_profile_index)) % TransportDebugSimulatorScript.LOSS_PROFILES.size()


func _enqueue_message(message: Dictionary) -> void:
	if not _connected:
		return
	var normalized := message.duplicate(true)
	var message_type := str(normalized.get(TransportMessageCodecScript.MESSAGE_TYPE_KEY, ""))
	if _debug_simulator.should_drop_message(message_type, _droppable_message_types):
		_debug_simulator.record_dropped()
		return
	var payload := TransportMessageCodecScript.encode_message(normalized)
	var decoded := TransportMessageCodecScript.decode_message(payload)
	if decoded.is_empty():
		_debug_simulator.record_dropped()
		return
	var deliver_tick := _current_tick + _debug_simulator.current_latency_ticks()
	_pending_entries.append({
		"deliver_tick": deliver_tick,
		"message": decoded,
	})
	_debug_simulator.record_enqueued()
