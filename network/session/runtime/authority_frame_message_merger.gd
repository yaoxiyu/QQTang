class_name AuthorityFrameMessageMerger
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func merge_server_frame(messages: Array[Dictionary]) -> Array[Dictionary]:
	var critical: Array[Dictionary] = []
	var terminal: Array[Dictionary] = []
	var latest_summary: Dictionary = {}
	var latest_summary_tick := -1
	var latest_checkpoint: Dictionary = {}
	var latest_checkpoint_tick := -1
	var ack_by_peer: Dictionary = {}
	var event_by_id: Dictionary = {}
	var passthrough: Array[Dictionary] = []

	for index in range(messages.size()):
		var message := messages[index]
		var message_type := _message_type(message)
		var tick := _message_tick(message)

		match message_type:
			TransportMessageTypesScript.STATE_SUMMARY, "AUTHORITY_DELTA":
				_collect_events(event_by_id, message, index)
				if tick >= latest_summary_tick:
					latest_summary_tick = tick
					latest_summary = message.duplicate(true)
			TransportMessageTypesScript.CHECKPOINT, TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
				_collect_events(event_by_id, message, index)
				if tick >= latest_checkpoint_tick:
					latest_checkpoint_tick = tick
					latest_checkpoint = message.duplicate(true)
			TransportMessageTypesScript.INPUT_ACK:
				var peer_id := int(message.get("peer_id", -1))
				var ack_tick := int(message.get("ack_tick", tick))
				if peer_id > 0 and ack_tick > int(ack_by_peer.get(peer_id, -1)):
					ack_by_peer[peer_id] = ack_tick
			TransportMessageTypesScript.MATCH_FINISHED:
				terminal.append(message.duplicate(true))
			TransportMessageTypesScript.MATCH_START, TransportMessageTypesScript.OPENING_SNAPSHOT, TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
				critical.append(message.duplicate(true))
			_:
				passthrough.append(message.duplicate(true))

	var result: Array[Dictionary] = []
	result.append_array(critical)

	if not latest_summary.is_empty():
		if not ack_by_peer.is_empty():
			latest_summary["ack_by_peer"] = ack_by_peer.duplicate(true)
		latest_summary["events"] = _sorted_events(event_by_id)
		result.append(latest_summary)
	elif not ack_by_peer.is_empty():
		result.append({
			"msg_type": "INPUT_ACK_BATCH",
			"message_type": "INPUT_ACK_BATCH",
			"ack_by_peer": ack_by_peer.duplicate(true),
		})

	if not latest_checkpoint.is_empty():
		result.append(latest_checkpoint)

	result.append_array(passthrough)
	result.append_array(terminal)
	return result


func _message_type(message: Dictionary) -> String:
	return String(message.get("message_type", message.get("msg_type", "")))


func _message_tick(message: Dictionary) -> int:
	return int(message.get("tick", message.get("snapshot_tick", message.get("ack_tick", -1))))


func _collect_events(event_by_id: Dictionary, message: Dictionary, original_index: int) -> void:
	var events: Variant = message.get("events", [])
	if not (events is Array):
		return
	var fallback_tick := _message_tick(message)
	for event_index in range(events.size()):
		var event: Variant = events[event_index]
		var event_tick := fallback_tick
		var event_type := -1
		var event_id := ""
		if event is Dictionary:
			event_tick = int(event.get("tick", fallback_tick))
			event_type = int(event.get("event_type", -1))
			event_id = String(event.get("event_id", ""))
		if event_id.is_empty():
			event_id = "%d:%d:%d:%d" % [event_tick, event_type, original_index, event_index]
		event_by_id[event_id] = {
			"sort_tick": event_tick,
			"sort_index": original_index * 10000 + event_index,
			"event": event,
		}


func _sorted_events(event_by_id: Dictionary) -> Array:
	var records: Array = event_by_id.values()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at := int(a.get("sort_tick", 0))
		var bt := int(b.get("sort_tick", 0))
		if at == bt:
			return int(a.get("sort_index", 0)) < int(b.get("sort_index", 0))
		return at < bt
	)
	var result: Array = []
	for record in records:
		result.append(record.get("event"))
	return result
