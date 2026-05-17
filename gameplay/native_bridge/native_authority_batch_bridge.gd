class_name NativeAuthorityBatchBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")


func coalesce_client_authority_batch(messages: Array, cursor: Dictionary = {}) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_authority_batch_coalescer:
		push_error("[native_authority_batch_bridge] native authority batch coalescer is disabled")
		return {}
	var native_kernel: Object = NativeKernelRuntimeScript.get_authority_batch_coalescer_kernel()
	if native_kernel == null:
		push_error("[native_authority_batch_bridge] native authority batch coalescer kernel is unavailable")
		return {}
	var raw_native_result: Variant = native_kernel.call("coalesce_client_authority_batch", messages, cursor)
	if not (raw_native_result is Dictionary):
		push_error("[native_authority_batch_bridge] native authority batch coalescer returned non-dictionary result")
		return {}
	var result := (raw_native_result as Dictionary).duplicate(true)
	_patch_revive_events_from_source_messages(result, messages)
	return result


func get_metrics() -> Dictionary:
	return {}


func _patch_revive_events_from_source_messages(result: Dictionary, messages: Array) -> void:
	var revive_payload_by_tick_and_player := _collect_revive_payloads(messages)
	if revive_payload_by_tick_and_player.is_empty():
		return
	var authority_events_by_tick: Variant = result.get("authority_events_by_tick", [])
	if not (authority_events_by_tick is Array):
		return
	for tick_entry_variant in authority_events_by_tick:
		if not (tick_entry_variant is Dictionary):
			continue
		var tick_entry := tick_entry_variant as Dictionary
		var tick_id := int(tick_entry.get("tick", -1))
		if tick_id < 0:
			continue
		var tick_revive_payloads: Dictionary = revive_payload_by_tick_and_player.get(tick_id, {})
		if tick_revive_payloads.is_empty():
			continue
		var events: Variant = tick_entry.get("events", [])
		if not (events is Array):
			continue
		for event_variant in events:
			if not (event_variant is Dictionary):
				continue
			var event_dict := event_variant as Dictionary
			if int(event_dict.get("event_type", -1)) != SimEventScript.EventType.PLAYER_REVIVED:
				continue
			var payload: Variant = event_dict.get("payload", {})
			if not (payload is Dictionary):
				continue
			var payload_dict := payload as Dictionary
			var player_id := int(payload_dict.get("player_id", -1))
			if player_id < 0:
				continue
			var source_payload: Dictionary = tick_revive_payloads.get(player_id, {})
			if source_payload.is_empty():
				continue
			if (not payload_dict.has("revive_type") or String(payload_dict.get("revive_type", "")).strip_edges().is_empty()) and source_payload.has("revive_type"):
				payload_dict["revive_type"] = source_payload.get("revive_type", "")
			if (not payload_dict.has("rescuer_player_id") or int(payload_dict.get("rescuer_player_id", -1)) <= 0) and source_payload.has("rescuer_player_id"):
				payload_dict["rescuer_player_id"] = int(source_payload.get("rescuer_player_id", -1))
			event_dict["payload"] = payload_dict


func _collect_revive_payloads(messages: Array) -> Dictionary:
	var result: Dictionary = {}
	for message_variant in messages:
		if not (message_variant is Dictionary):
			continue
		var message := message_variant as Dictionary
		var fallback_tick := int(message.get("tick", 0))
		var events := _message_events(message)
		if events.is_empty():
			continue
		for event_variant in events:
			if not (event_variant is Dictionary):
				continue
			var event_dict := event_variant as Dictionary
			if int(event_dict.get("event_type", -1)) != SimEventScript.EventType.PLAYER_REVIVED:
				continue
			var payload: Variant = event_dict.get("payload", {})
			if not (payload is Dictionary):
				continue
			var payload_dict := payload as Dictionary
			var player_id := int(payload_dict.get("player_id", -1))
			if player_id < 0:
				continue
			var event_tick := int(event_dict.get("tick", fallback_tick))
			if not result.has(event_tick):
				result[event_tick] = {}
			var by_player: Dictionary = result[event_tick]
			var previous: Dictionary = by_player.get(player_id, {})
			if _revive_payload_score(payload_dict) >= _revive_payload_score(previous):
				by_player[player_id] = payload_dict.duplicate(true)
				result[event_tick] = by_player
	return result


func _message_events(message: Dictionary) -> Array:
	var events: Variant = message.get("events", [])
	if events is Array and not events.is_empty():
		return events
	var event_details: Variant = message.get("event_details", [])
	if event_details is Array:
		return event_details
	return []


func _revive_payload_score(payload: Dictionary) -> int:
	if payload.is_empty():
		return 0
	var score := payload.size()
	var revive_type := String(payload.get("revive_type", "")).strip_edges()
	if not revive_type.is_empty():
		score += 8
	if int(payload.get("rescuer_player_id", -1)) > 0:
		score += 8
	return score
