class_name AuthorityCheckpointBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const BattleWireBudgetProfilerScript = preload("res://network/session/runtime/battle_wire_budget_profiler.gd")

var _profiler: RefCounted = BattleWireBudgetProfilerScript.new()
var _last_profile: Dictionary = {}
var _last_wall_sync_count: int = -1


func build_checkpoint(active_match: BattleMatch, snapshot: WorldSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	var current_breakable := int(snapshot.breakable_blocks_remaining)
	var force_walls := current_breakable != _last_wall_sync_count
	var walls_payload: Array[Dictionary] = []
	if force_walls:
		walls_payload = snapshot.walls
		_last_wall_sync_count = current_breakable
	var checkpoint := {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"msg_type": TransportMessageTypesScript.CHECKPOINT,
		"wire_version": BattleWireBudgetContractScript.WIRE_VERSION,
		"tick": snapshot.tick_id,
		"players": snapshot.players,
		"player_summary": active_match.build_player_position_summary() if active_match != null else [],
		"bubbles": snapshot.bubbles,
		"items": snapshot.items,
		"walls": walls_payload,
		"breakable_blocks_remaining": current_breakable,
		"airplane": _build_airplane_payload(snapshot.item_pool_runtime),
		"match_state": snapshot.match_state.duplicate(true),
		"mode_state": snapshot.mode_state.duplicate(true),
		"rng_state": snapshot.rng_state,
		"checksum": snapshot.checksum,
	}
	_last_profile = _profiler.profile_checkpoint(checkpoint, var_to_bytes(checkpoint).size())
	return checkpoint


func build_metrics() -> Dictionary:
	return {
		"last_checkpoint_profile": _last_profile.duplicate(true),
		"battle_wire_budget": _profiler.build_metrics(),
	}


func reset() -> void:
	_last_profile.clear()
	_last_wall_sync_count = -1
	_profiler.reset()


func _build_airplane_payload(item_pool_runtime: Dictionary) -> Dictionary:
	if item_pool_runtime.is_empty():
		return {}
	return {
		"active": bool(item_pool_runtime.get("airplane_active", false)),
		"x": float(item_pool_runtime.get("airplane_x", 0.0)),
		"y": int(item_pool_runtime.get("airplane_y", 0)),
	}
