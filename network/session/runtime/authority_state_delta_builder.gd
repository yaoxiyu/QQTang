class_name AuthorityStateDeltaBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const BattleWireBudgetProfilerScript = preload("res://network/session/runtime/battle_wire_budget_profiler.gd")

var _previous_bubbles_by_id: Dictionary = {}
var _previous_items_by_id: Dictionary = {}
var _previous_tick: int = -1
var _profiler: RefCounted = BattleWireBudgetProfilerScript.new()
var _last_profile: Dictionary = {}


func build_delta(_active_match: BattleMatch, snapshot: WorldSnapshot, tick_id: int, events: Array = []) -> Dictionary:
	if snapshot == null:
		return {}
	var current_bubbles := _index_by_entity_id(snapshot.bubbles)
	var current_items := _index_by_entity_id(snapshot.items)
	var changed_bubbles := _collect_changed_entries(current_bubbles, _previous_bubbles_by_id)
	var removed_bubble_ids := _collect_removed_ids(current_bubbles, _previous_bubbles_by_id)
	var changed_items := _collect_changed_entries(current_items, _previous_items_by_id)
	var removed_item_ids := _collect_removed_ids(current_items, _previous_items_by_id)
	_previous_bubbles_by_id = current_bubbles.duplicate(true)
	_previous_items_by_id = current_items.duplicate(true)
	var base_tick := _previous_tick
	_previous_tick = tick_id
	if changed_bubbles.is_empty() and removed_bubble_ids.is_empty() and changed_items.is_empty() and removed_item_ids.is_empty() and events.is_empty():
		return {}
	var delta := {
		"message_type": TransportMessageTypesScript.STATE_DELTA,
		"msg_type": TransportMessageTypesScript.STATE_DELTA,
		"wire_version": BattleWireBudgetContractScript.WIRE_VERSION,
		"tick": tick_id,
		"base_tick": base_tick,
		"changed_bubbles": changed_bubbles,
		"removed_bubble_ids": removed_bubble_ids,
		"changed_items": changed_items,
		"removed_item_ids": removed_item_ids,
		"event_details": events,
		"events": events,
	}
	_last_profile = _profiler.profile_state_summary({
		"player_summary": [],
		"bubbles": changed_bubbles,
		"items": changed_items,
		"events": events,
		"match_state": {},
	}, var_to_bytes(delta).size())
	return delta


func build_metrics() -> Dictionary:
	return {
		"last_state_delta_profile": _last_profile.duplicate(true),
		"battle_wire_budget": _profiler.build_metrics(),
	}


func reset() -> void:
	_previous_bubbles_by_id.clear()
	_previous_items_by_id.clear()
	_previous_tick = -1
	_last_profile.clear()
	_profiler.reset()


func _index_by_entity_id(entries: Array[Dictionary]) -> Dictionary:
	var indexed: Dictionary = {}
	for entry in entries:
		var entity_id := int(entry.get("entity_id", -1))
		if entity_id < 0:
			continue
		indexed[entity_id] = entry.duplicate(true)
	return indexed


func _collect_changed_entries(current: Dictionary, previous: Dictionary) -> Array:
	var changed: Array = []
	for entity_id in current.keys():
		var current_entry: Dictionary = current[entity_id]
		if not previous.has(entity_id) or var_to_bytes(previous[entity_id]) != var_to_bytes(current_entry):
			changed.append(current_entry.duplicate(true))
	return changed


func _collect_removed_ids(current: Dictionary, previous: Dictionary) -> Array[int]:
	var removed: Array[int] = []
	for entity_id in previous.keys():
		if not current.has(entity_id):
			removed.append(int(entity_id))
	return removed
