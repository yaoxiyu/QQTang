class_name AuthorityCheckpointBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const BattleWireBudgetProfilerScript = preload("res://network/session/runtime/battle_wire_budget_profiler.gd")

const WALL_REDUNDANCY_SENDS := 5

var _profiler: RefCounted = BattleWireBudgetProfilerScript.new()
var _last_profile: Dictionary = {}
var _last_wall_sync_count: int = -1
var _last_snapshot_walls: Dictionary = {}
var _wall_change_log: Array[Dictionary] = []


func build_checkpoint(active_match: BattleMatch, snapshot: WorldSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	var current_breakable := int(snapshot.breakable_blocks_remaining)
	var force_walls := current_breakable != _last_wall_sync_count
	var walls_payload: Array[Dictionary] = []

	var current_walls := _index_walls_by_cell(snapshot.walls)
	if not _last_snapshot_walls.is_empty():
		for key in current_walls.keys():
			var current: Dictionary = current_walls[key]
			if not _last_snapshot_walls.has(key) or var_to_bytes(_last_snapshot_walls[key]) != var_to_bytes(current):
				_wall_change_log.append({
					"key": key,
					"wall": current.duplicate(true),
					"remaining_sends": WALL_REDUNDANCY_SENDS,
				})
	_last_snapshot_walls = current_walls.duplicate(true)

	if force_walls:
		walls_payload = snapshot.walls
		_last_wall_sync_count = current_breakable
		_decr_all_remaining_sends()
	else:
		var deduped: Dictionary = {}
		for entry in _wall_change_log:
			var key: String = entry["key"]
			if not deduped.has(key):
				deduped[key] = entry
		for entry in deduped.values():
			walls_payload.append(entry["wall"])
			entry["remaining_sends"] = int(entry["remaining_sends"]) - 1
	_prune_acknowledged()

	var checkpoint := {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
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
	_last_snapshot_walls.clear()
	_wall_change_log.clear()
	_profiler.reset()


func _decr_all_remaining_sends() -> void:
	for entry in _wall_change_log:
		entry["remaining_sends"] = int(entry["remaining_sends"]) - 1


func _prune_acknowledged() -> void:
	var kept: Array[Dictionary] = []
	for entry in _wall_change_log:
		if int(entry["remaining_sends"]) > 0:
			kept.append(entry)
	_wall_change_log = kept


func _build_airplane_payload(item_pool_runtime: Dictionary) -> Dictionary:
	if item_pool_runtime.is_empty():
		return {}
	return {
		"active": bool(item_pool_runtime.get("airplane_active", false)),
		"x": float(item_pool_runtime.get("airplane_x", 0.0)),
		"y": int(item_pool_runtime.get("airplane_y", 0)),
	}


func _index_walls_by_cell(walls: Array[Dictionary]) -> Dictionary:
	var indexed: Dictionary = {}
	for wall in walls:
		var cell_x := int(wall.get("cell_x", -1))
		var cell_y := int(wall.get("cell_y", -1))
		if cell_x < 0 or cell_y < 0:
			continue
		indexed["%d,%d" % [cell_x, cell_y]] = wall.duplicate(true)
	return indexed
