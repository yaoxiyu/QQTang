class_name Phase2LocalMessagePipe
extends RefCounted

var latency_ms: int = 0
var packet_loss: float = 0.0

var _clock_ms: float = 0.0
var _rng := RandomNumberGenerator.new()
var _queued_inputs: Array[Dictionary] = []
var _queued_client_messages: Dictionary = {}


func _init() -> void:
	_rng.seed = 20260326


func reset() -> void:
	_clock_ms = 0.0
	_queued_inputs.clear()
	_queued_client_messages.clear()


func configure(p_latency_ms: int, p_packet_loss: float) -> void:
	latency_ms = max(0, p_latency_ms)
	packet_loss = clampf(p_packet_loss, 0.0, 1.0)


func advance(delta_ms: float) -> void:
	_clock_ms += max(delta_ms, 0.0)


func queue_input(frame: PlayerInputFrame) -> void:
	if frame == null:
		return
	if _should_drop_packet():
		return

	_queued_inputs.append({
		"deliver_ms": _clock_ms + float(latency_ms),
		"frame": frame.duplicate_for_tick(frame.tick_id)
	})


func flush_server_inputs() -> Array[PlayerInputFrame]:
	var ready: Array[PlayerInputFrame] = []
	var pending: Array[Dictionary] = []

	for entry in _queued_inputs:
		if float(entry.get("deliver_ms", 0.0)) <= _clock_ms:
			ready.append(entry.get("frame"))
		else:
			pending.append(entry)

	_queued_inputs = pending
	return ready


func queue_client_message(peer_id: int, message: Dictionary) -> void:
	if _should_drop_packet():
		return
	if not _queued_client_messages.has(peer_id):
		_queued_client_messages[peer_id] = []

	var peer_queue: Array = _queued_client_messages[peer_id]
	peer_queue.append({
		"deliver_ms": _clock_ms + float(latency_ms),
		"message": message.duplicate(true)
	})


func flush_client_messages(peer_id: int) -> Array[Dictionary]:
	if not _queued_client_messages.has(peer_id):
		return []

	var ready: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for entry in _queued_client_messages[peer_id]:
		if float(entry.get("deliver_ms", 0.0)) <= _clock_ms:
			ready.append(entry.get("message"))
		else:
			pending.append(entry)

	_queued_client_messages[peer_id] = pending
	return ready


func _should_drop_packet() -> bool:
	return packet_loss > 0.0 and _rng.randf() < packet_loss
