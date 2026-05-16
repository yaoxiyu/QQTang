class_name AuthorityFrameMessageMerger
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func merge_server_frame(messages: Array[Dictionary]) -> Array[Dictionary]:
	var critical: Array[Dictionary] = []
	var terminal: Array[Dictionary] = []
	var latest_summary: Dictionary = {}
	var latest_summary_tick := -1
	var latest_delta: Dictionary = {}
	var latest_delta_tick := -1
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
			TransportMessageTypesScript.STATE_SUMMARY:
				_collect_events(event_by_id, message, index)
				if tick >= latest_summary_tick:
					latest_summary_tick = tick
					latest_summary = message.duplicate(true)
			TransportMessageTypesScript.STATE_DELTA:
				_collect_events(event_by_id, message, index)
				if tick >= latest_delta_tick:
					latest_delta_tick = tick
					latest_delta = message.duplicate(true)
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
			"message_type": "INPUT_ACK_BATCH",
			"ack_by_peer": ack_by_peer.duplicate(true),
		})

	if not latest_delta.is_empty():
		result.append(latest_delta)

	if not latest_checkpoint.is_empty():
		result.append(latest_checkpoint)

	result.append_array(passthrough)
	result.append_array(terminal)
	return result


func _message_type(message: Dictionary) -> String:
	return String(message.get("message_type", ""))


func _message_tick(message: Dictionary) -> int:
	return int(message.get("tick", message.get("snapshot_tick", message.get("ack_tick", -1))))


func _collect_events(event_by_id: Dictionary, message: Dictionary, original_index: int) -> void:
	var events: Variant = _message_events(message)
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
			event_id = _event_id(event, event_tick, event_type, original_index, event_index)
		var existing: Dictionary = event_by_id.get(event_id, {})
		if not existing.is_empty() and _event_payload_score(existing.get("event")) > _event_payload_score(event):
			continue
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


func _message_events(message: Dictionary) -> Variant:
	var events: Variant = message.get("events", [])
	if events is Array and not events.is_empty():
		return events
	return message.get("event_details", [])


func _event_id(event: Variant, event_tick: int, event_type: int, original_index: int, event_index: int) -> String:
	if not (event is Dictionary):
		return "%d:%d:%d:%d" % [event_tick, event_type, original_index, event_index]
	var event_dict: Dictionary = event
	var payload: Dictionary = event_dict.get("payload", {}) if event_dict.get("payload", {}) is Dictionary else {}
	var source_id := int(event_dict.get("source_id", event_dict.get("entity_id", event_dict.get("bubble_id", payload.get("bubble_id", payload.get("entity_id", -1))))))
	var sequence := int(event_dict.get("sequence", event_dict.get("seq", -1)))
	if source_id >= 0 or sequence >= 0:
		return "%d:%d:%d:%d" % [event_tick, event_type, source_id, sequence]
	return "%d:%d:%d:%d" % [event_tick, event_type, original_index, event_index]


func _event_payload_score(event: Variant) -> int:
	if not (event is Dictionary):
		return 0
	var payload: Variant = (event as Dictionary).get("payload", {})
	if not (payload is Dictionary):
		return 0
	var score := (payload as Dictionary).size()
	var covered_cells: Variant = (payload as Dictionary).get("covered_cells", [])
	if covered_cells is Array:
		score += (covered_cells as Array).size()
	return score
