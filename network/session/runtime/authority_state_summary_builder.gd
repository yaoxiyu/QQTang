class_name AuthorityStateSummaryBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const BattleWireBudgetProfilerScript = preload("res://network/session/runtime/battle_wire_budget_profiler.gd")

var _profiler: RefCounted = BattleWireBudgetProfilerScript.new()
var _last_profile: Dictionary = {}


func build_core(active_match: BattleMatch, snapshot: WorldSnapshot, tick_id: int, events: Array) -> Dictionary:
	var match_state: Dictionary = snapshot.match_state if snapshot != null else {}
	var summary := {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"wire_version": BattleWireBudgetContractScript.WIRE_VERSION,
		"tick": tick_id,
		"checksum": int(snapshot.checksum) if snapshot != null else 0,
			"breakable_blocks_remaining": int(snapshot.breakable_blocks_remaining) if snapshot != null else -1,
		"airplane": _build_airplane_payload(snapshot.item_pool_runtime if snapshot != null else {}),
		"player_summary": active_match.build_player_position_summary() if active_match != null else [],
		"match_phase": int(match_state.get("phase", 0)),
		"remaining_ticks": int(match_state.get("remaining_ticks", 0)),
		"events": _build_short_events(events),
	}
	_last_profile = _profiler.profile_state_summary(summary, var_to_bytes(summary).size())
	return summary


func build_metrics() -> Dictionary:
	return {
		"last_state_summary_profile": _last_profile.duplicate(true),
		"battle_wire_budget": _profiler.build_metrics(),
	}


func reset() -> void:
	_last_profile.clear()
	_profiler.reset()


func _build_short_events(events: Array) -> Array:
	var short_events: Array = []
	for event in events:
		if not (event is Dictionary):
			continue
		var event_dict := event as Dictionary
		short_events.append({
			"tick": int(event_dict.get("tick", 0)),
			"event_type": int(event_dict.get("event_type", 0)),
			"payload": _minimize_event_payload(event_dict.get("payload", {})),
		})
	return short_events


func _minimize_event_payload(payload: Variant) -> Dictionary:
	var minimized: Dictionary = {}
	if not (payload is Dictionary):
		return minimized
	var payload_dict := payload as Dictionary
	for key in ["entity_id", "bubble_id", "item_id", "owner_player_id", "player_id", "cell_x", "cell_y", "can_spawn_item"]:
		if payload_dict.has(key):
			minimized[key] = payload_dict[key]
	return minimized


func _build_airplane_payload(item_pool_runtime: Dictionary) -> Dictionary:
	if item_pool_runtime.is_empty():
		return {}
	return {
		"active": bool(item_pool_runtime.get("airplane_active", false)),
		"x": float(item_pool_runtime.get("airplane_x", 0.0)),
		"y": int(item_pool_runtime.get("airplane_y", 0)),
	}
