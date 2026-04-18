class_name FakeTransport
extends Node

var latency_ticks: int = 0
var jitter_ticks: int = 0
var packet_loss_every: int = 0
var duplicate_every: int = 0
var enable_out_of_order: bool = false

var delivered_count: int = 0
var dropped_count: int = 0
var duplicated_count: int = 0

var _sequence: int = 0
var _queue: Array[Dictionary] = []


func configure(config: Dictionary = {}) -> void:
	latency_ticks = int(config.get("latency_ticks", 0))
	jitter_ticks = int(config.get("jitter_ticks", 0))
	packet_loss_every = int(config.get("packet_loss_every", 0))
	duplicate_every = int(config.get("duplicate_every", 0))
	enable_out_of_order = bool(config.get("enable_out_of_order", false))


func send(direction: String, payload, current_tick: int) -> void:
	_sequence += 1
	if packet_loss_every > 0 and _sequence % packet_loss_every == 0:
		dropped_count += 1
		return

	_enqueue(direction, payload, current_tick, false)
	if duplicate_every > 0 and _sequence % duplicate_every == 0:
		duplicated_count += 1
		_enqueue(direction, payload, current_tick, true)


func pop_ready(direction: String, current_tick: int) -> Array:
	var ready: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for item in _queue:
		if String(item.get("direction", "")) == direction and int(item.get("deliver_tick", 0)) <= current_tick:
			ready.append(item)
		else:
			pending.append(item)
	_queue = pending

	ready.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a["deliver_tick"]) == int(b["deliver_tick"]):
			return int(a["sequence"]) < int(b["sequence"])
		return int(a["deliver_tick"]) < int(b["deliver_tick"])
	)

	if enable_out_of_order and ready.size() > 1:
		ready.reverse()

	var payloads: Array = []
	for item in ready:
		delivered_count += 1
		payloads.append(item["payload"])
	return payloads


func has_pending() -> bool:
	return not _queue.is_empty()


func pending_count() -> int:
	return _queue.size()


func _enqueue(direction: String, payload, current_tick: int, is_duplicate: bool) -> void:
	var jitter := _compute_jitter(_sequence, is_duplicate)
	var deliver_tick := current_tick + latency_ticks + jitter
	if deliver_tick < current_tick:
		deliver_tick = current_tick
	_queue.append({
		"sequence": _sequence,
		"direction": direction,
		"deliver_tick": deliver_tick,
		"payload": payload
	})


func _compute_jitter(sequence_id: int, is_duplicate: bool) -> int:
	if jitter_ticks <= 0:
		return 0
	var sign := -1 if sequence_id % 2 == 0 else 1
	if is_duplicate:
		sign *= -1
	return sign * jitter_ticks
