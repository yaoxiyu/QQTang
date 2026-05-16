class_name AuthorityBatchCoalescer
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func coalesce_client_authority_batch(messages: Array, cursor: Dictionary = {}) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var result: Dictionary = _empty_result()
	var known_tick: int = max(int(cursor.get("latest_authoritative_tick", -1)), int(cursor.get("latest_snapshot_tick", -1)))
	var ack_by_peer: Dictionary = {}
	var summary_message: Dictionary = {}
	var summary_tick := -1
	var delta_message: Dictionary = {}
	var delta_tick := -1
	var snapshot_message: Dictionary = {}
	var snapshot_tick := -1
	var events_by_tick: Dictionary = {}
	var event_ids: Dictionary = {}
	var raw_ack_count := 0
	var raw_summary_count := 0
	var raw_delta_count := 0
	var raw_checkpoint_count := 0
	var raw_auth_snapshot_count := 0
	var dropped_stale_count := 0
	var dropped_intermediate_count := 0
	var dropped_stale_summary_count := 0
	var dropped_intermediate_summary_count := 0
	var preserved_event_count := 0
	var dropped_snapshot_ticks := PackedInt32Array()

	for index in range(messages.size()):
		var raw_message: Variant = messages[index]
		if not (raw_message is Dictionary):
			continue
		var message: Dictionary = raw_message
		var message_type: String = _message_type(message)
		if _is_authority_sync_type(message_type):
			preserved_event_count += _append_events(events_by_tick, event_ids, message, index)
		if message_type == TransportMessageTypesScript.INPUT_ACK:
			raw_ack_count += 1
			var peer_id: int = int(message.get("peer_id", message.get("sender_peer_id", -1)))
			var ack_tick: int = int(message.get("ack_tick", message.get("tick", 0)))
			if not ack_by_peer.has(peer_id) or ack_tick > int((ack_by_peer[peer_id] as Dictionary).get("ack_tick", 0)):
				var ack_message: Dictionary = message.duplicate(true)
				ack_message["ack_tick"] = ack_tick
				ack_message["peer_id"] = peer_id
				ack_by_peer[peer_id] = ack_message
		elif message_type == TransportMessageTypesScript.STATE_SUMMARY:
			raw_summary_count += 1
			var tick: int = _message_tick(message)
			if tick <= known_tick:
				dropped_stale_summary_count += 1
			elif summary_message.is_empty() or tick >= summary_tick:
				if not summary_message.is_empty():
					dropped_intermediate_summary_count += 1
				summary_tick = tick
				summary_message = message.duplicate(true)
			else:
				dropped_intermediate_summary_count += 1
		elif message_type == TransportMessageTypesScript.STATE_DELTA:
			raw_delta_count += 1
			var tick: int = _message_tick(message)
			if tick <= known_tick:
				dropped_stale_summary_count += 1
			elif delta_message.is_empty() or tick >= delta_tick:
				delta_tick = tick
				delta_message = message.duplicate(true)
		elif _is_snapshot_type(message_type):
			if message_type == TransportMessageTypesScript.CHECKPOINT:
				raw_checkpoint_count += 1
			else:
				raw_auth_snapshot_count += 1
			var tick: int = _message_tick(message)
			if tick <= known_tick:
				dropped_stale_count += 1
				dropped_snapshot_ticks.append(tick)
			elif snapshot_message.is_empty() or tick >= snapshot_tick:
				if not snapshot_message.is_empty():
					dropped_intermediate_count += 1
					dropped_snapshot_ticks.append(snapshot_tick)
				snapshot_tick = tick
				snapshot_message = message.duplicate(true)
			else:
				dropped_intermediate_count += 1
				dropped_snapshot_ticks.append(tick)
		elif _is_terminal_type(message_type):
			result["terminal_messages"].append(message.duplicate(true))
		else:
			result["passthrough_messages"].append(message.duplicate(true))

	result["input_acks"] = _ack_array_from_peer_map(ack_by_peer)
	result["latest_state_summary"] = summary_message
	result["latest_state_delta"] = delta_message
	result["latest_snapshot_message"] = snapshot_message
	result["authority_events_by_tick"] = _events_array_from_tick_map(events_by_tick)
	result["dropped_snapshot_ticks"] = dropped_snapshot_ticks
	result["metrics"] = _make_metrics(
		messages.size(),
		raw_ack_count,
		raw_summary_count,
		raw_delta_count,
		raw_checkpoint_count,
		raw_auth_snapshot_count,
		result["input_acks"].size(),
		summary_tick,
		delta_tick,
		snapshot_tick,
		dropped_stale_summary_count,
		dropped_intermediate_summary_count,
		dropped_stale_count,
		dropped_intermediate_count,
		result["authority_events_by_tick"].size(),
		preserved_event_count,
		result["terminal_messages"].size(),
		result["passthrough_messages"].size(),
		Time.get_ticks_usec() - started_usec
	)
	return result


func _empty_result() -> Dictionary:
	return {
		"input_acks": [],
		"latest_state_summary": {},
		"latest_state_delta": {},
		"latest_snapshot_message": {},
		"authority_events_by_tick": [],
		"terminal_messages": [],
		"passthrough_messages": [],
		"dropped_snapshot_ticks": PackedInt32Array(),
		"metrics": {},
	}


func _message_type(message: Dictionary) -> String:
	return String(message.get("message_type", ""))


func _message_tick(message: Dictionary) -> int:
	return int(message.get("tick", message.get("snapshot_tick", message.get("ack_tick", 0))))


func _append_events(events_by_tick: Dictionary, event_ids: Dictionary, message: Dictionary, original_index: int) -> int:
	var events: Variant = _message_events(message)
	if not (events is Array) or events.is_empty():
		return 0
	var fallback_tick := _message_tick(message)
	var appended_count := 0
	for event_index in range(events.size()):
		var event: Variant = events[event_index]
		var event_tick: int = fallback_tick
		var event_id := ""
		if event is Dictionary:
			var event_dict: Dictionary = event
			event_tick = int(event_dict.get("tick", fallback_tick))
			event_id = _event_id(event_dict, event_tick, original_index, event_index)
		else:
			event_id = "%d:-1:%d:%d" % [event_tick, original_index, event_index]
		if event_ids.has(event_id):
			var previous: Dictionary = event_ids[event_id]
			if _event_payload_score(previous.get("event")) >= _event_payload_score(event):
				continue
			_remove_event_record(events_by_tick, previous)
			appended_count -= 1
		event_ids[event_id] = true
		if not events_by_tick.has(event_tick):
			events_by_tick[event_tick] = []
		var record := {
			"original_index": original_index,
			"event_index": event_index,
			"event": event,
			"tick": event_tick,
			"event_id": event_id,
		}
		(events_by_tick[event_tick] as Array).append(record)
		event_ids[event_id] = record
		appended_count += 1
	return appended_count


func _event_id(event: Dictionary, event_tick: int, original_index: int, event_index: int) -> String:
	var explicit_id := String(event.get("event_id", ""))
	if not explicit_id.is_empty():
		return explicit_id
	var event_type := int(event.get("event_type", -1))
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	var source_id := int(event.get("source_id", event.get("entity_id", event.get("bubble_id", payload.get("bubble_id", payload.get("entity_id", -1))))))
	var sequence := int(event.get("sequence", event.get("seq", -1)))
	if source_id >= 0 or sequence >= 0:
		return "%d:%d:%d:%d" % [event_tick, event_type, source_id, sequence]
	return "%d:%d:%d:%d" % [event_tick, event_type, original_index, event_index]


func _message_events(message: Dictionary) -> Variant:
	var events: Variant = message.get("events", [])
	if events is Array and not events.is_empty():
		return events
	return message.get("event_details", [])


func _remove_event_record(events_by_tick: Dictionary, record: Dictionary) -> void:
	var tick := int(record.get("tick", -1))
	if not events_by_tick.has(tick):
		return
	var records: Array = events_by_tick[tick]
	for index in range(records.size() - 1, -1, -1):
		var candidate: Dictionary = records[index]
		if String(candidate.get("event_id", "")) == String(record.get("event_id", "")):
			records.remove_at(index)
	if records.is_empty():
		events_by_tick.erase(tick)


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


func _is_authority_sync_type(message_type: String) -> bool:
	return message_type == TransportMessageTypesScript.INPUT_ACK \
		or message_type == TransportMessageTypesScript.STATE_SUMMARY \
		or message_type == TransportMessageTypesScript.STATE_DELTA \
		or _is_snapshot_type(message_type) \
		or _is_terminal_type(message_type)


func _is_snapshot_type(message_type: String) -> bool:
	return message_type == TransportMessageTypesScript.CHECKPOINT \
		or message_type == TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT


func _is_terminal_type(message_type: String) -> bool:
	return message_type == TransportMessageTypesScript.MATCH_FINISHED


func _ack_array_from_peer_map(ack_by_peer: Dictionary) -> Array:
	var peer_ids := ack_by_peer.keys()
	peer_ids.sort()
	var result: Array = []
	for peer_id in peer_ids:
		result.append((ack_by_peer[peer_id] as Dictionary).duplicate(true))
	return result


func _events_array_from_tick_map(events_by_tick: Dictionary) -> Array:
	var ticks := events_by_tick.keys()
	ticks.sort()
	var result: Array = []
	for tick in ticks:
		var event_records: Array = events_by_tick[tick]
		event_records.sort_custom(_compare_event_records)
		var events: Array = []
		for record in event_records:
			events.append((record as Dictionary).get("event"))
		result.append({
			"tick": int(tick),
			"events": events,
		})
	return result


func _compare_event_records(left: Dictionary, right: Dictionary) -> bool:
	var left_message_index := int(left.get("original_index", 0))
	var right_message_index := int(right.get("original_index", 0))
	if left_message_index == right_message_index:
		return int(left.get("event_index", 0)) < int(right.get("event_index", 0))
	return left_message_index < right_message_index


func _make_metrics(
	incoming_batch_size: int,
	raw_ack_count: int,
	raw_summary_count: int,
	raw_delta_count: int,
	raw_checkpoint_count: int,
	raw_auth_snapshot_count: int,
	coalesced_ack_count: int,
	coalesced_summary_tick: int,
	coalesced_delta_tick: int,
	coalesced_snapshot_tick: int,
	dropped_stale_summary_count: int,
	dropped_intermediate_summary_count: int,
	dropped_stale_snapshot_count: int,
	dropped_intermediate_snapshot_count: int,
	preserved_event_tick_count: int,
	preserved_event_count: int,
	terminal_message_count: int,
	passthrough_message_count: int,
	coalesce_usec: int
) -> Dictionary:
	return {
		"incoming_batch_size": incoming_batch_size,
		"raw_ack_count": raw_ack_count,
		"raw_summary_count": raw_summary_count,
		"raw_delta_count": raw_delta_count,
		"raw_checkpoint_count": raw_checkpoint_count,
		"raw_auth_snapshot_count": raw_auth_snapshot_count,
		"coalesced_ack_count": coalesced_ack_count,
		"coalesced_summary_tick": coalesced_summary_tick,
		"coalesced_delta_tick": coalesced_delta_tick,
		"coalesced_snapshot_tick": coalesced_snapshot_tick,
		"dropped_stale_summary_count": dropped_stale_summary_count,
		"dropped_intermediate_summary_count": dropped_intermediate_summary_count,
		"dropped_stale_snapshot_count": dropped_stale_snapshot_count,
		"dropped_intermediate_snapshot_count": dropped_intermediate_snapshot_count,
		"preserved_event_tick_count": preserved_event_tick_count,
		"preserved_event_count": preserved_event_count,
		"terminal_message_count": terminal_message_count,
		"passthrough_message_count": passthrough_message_count,
		"coalesce_usec": coalesce_usec,
	}
