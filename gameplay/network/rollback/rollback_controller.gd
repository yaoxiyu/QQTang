class_name RollbackController
extends Node

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const NativeSnapshotDiffBridgeScript = preload("res://gameplay/native_bridge/native_snapshot_diff_bridge.gd")
const NativeRollbackPlannerBridgeScript = preload("res://gameplay/native_bridge/native_rollback_planner_bridge.gd")

const PLAN_NOOP := 0
const PLAN_ROLLBACK := 1
const PLAN_FORCE_RESYNC := 2
const PLAN_DROP_STALE_AUTHORITY := 3
const MAX_SYNC_REPLAY_TICKS := 8
const MAX_DEFERRED_REPLAY_TICKS := 32

signal prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i)
signal full_visual_resync(snapshot: WorldSnapshot)

var predicted_sim_world: SimWorld = null
var snapshot_service: SnapshotService = null
var snapshot_buffer: SnapshotBuffer = SnapshotBuffer.new()
var local_input_buffer: InputRingBuffer = InputRingBuffer.new()

var local_peer_id: int = 0
var last_authoritative_tick: int = 0
var max_rollback_window: int = 16
var compare_bubbles: bool = true
var compare_items: bool = true
var rollback_count: int = 0
var last_rollback_from_tick: int = -1
var avg_replay_ticks: float = 0.0
var last_replay_tick_count: int = 0
var total_replay_ticks: int = 0
var force_resync_count: int = 0
var predicted_until_tick: int = 0
var ignored_local_player_keys: Array[String] = []
var _native_snapshot_diff_bridge: RefCounted = NativeSnapshotDiffBridgeScript.new()
var _native_rollback_planner_bridge: RefCounted = NativeRollbackPlannerBridgeScript.new()
var _last_native_planner_metrics: Dictionary = {}


func configure(
	p_predicted_sim_world: SimWorld,
	p_snapshot_service: SnapshotService,
	p_snapshot_buffer: SnapshotBuffer,
	p_local_input_buffer: InputRingBuffer,
	p_local_peer_id: int,
	p_max_rollback_window: int = 16,
	p_compare_bubbles: bool = true,
	p_compare_items: bool = true,
	p_ignored_local_player_keys: Array[String] = []
) -> void:
	predicted_sim_world = p_predicted_sim_world
	snapshot_service = p_snapshot_service
	snapshot_buffer = p_snapshot_buffer
	local_input_buffer = p_local_input_buffer
	local_peer_id = p_local_peer_id
	max_rollback_window = max(1, p_max_rollback_window)
	compare_bubbles = p_compare_bubbles
	compare_items = p_compare_items
	ignored_local_player_keys = p_ignored_local_player_keys.duplicate()
	predicted_until_tick = 0


func dispose() -> void:
	predicted_sim_world = null
	snapshot_service = null
	if snapshot_buffer != null:
		snapshot_buffer.clear()
	if local_input_buffer != null:
		local_input_buffer.clear()
	snapshot_buffer = null
	local_input_buffer = null
	local_peer_id = 0
	last_authoritative_tick = 0
	compare_bubbles = true
	compare_items = true
	rollback_count = 0
	last_rollback_from_tick = -1
	avg_replay_ticks = 0.0
	last_replay_tick_count = 0
	total_replay_ticks = 0
	force_resync_count = 0
	predicted_until_tick = 0
	ignored_local_player_keys.clear()


func set_predicted_until_tick(tick_id: int) -> void:
	predicted_until_tick = tick_id


func on_authoritative_snapshot(snapshot: WorldSnapshot) -> bool:
	if snapshot == null:
		return false

	last_authoritative_tick = snapshot.tick_id
	if predicted_sim_world == null:
		return false

	var local_snapshot := snapshot_buffer.get_snapshot(snapshot.tick_id)
	if local_snapshot == null:
		_force_resync(snapshot)
		return true

	var diff_result := describe_snapshot_diff(local_snapshot, snapshot)
	var plan := _plan_rollback(snapshot, local_snapshot, diff_result)
	match int(plan.get("decision", PLAN_NOOP)):
		PLAN_NOOP:
			return false
		PLAN_FORCE_RESYNC:
			_force_resync(snapshot)
			return true
		PLAN_ROLLBACK:
			_rollback_from_snapshot(snapshot)
			return true
		PLAN_DROP_STALE_AUTHORITY:
			return false
		_:
			return false


func describe_snapshot_diff(local_snapshot: WorldSnapshot, authoritative_snapshot: WorldSnapshot) -> Dictionary:
	if _native_snapshot_diff_bridge == null:
		return {}
	return _native_snapshot_diff_bridge.diff_snapshots(
		_snapshot_to_diff_dict(local_snapshot),
		_snapshot_to_diff_dict(authoritative_snapshot),
		_diff_options()
	)


func get_native_rollback_metrics() -> Dictionary:
	var metrics := _last_native_planner_metrics.duplicate(true)
	if _native_snapshot_diff_bridge != null:
		metrics["snapshot_diff"] = _native_snapshot_diff_bridge.get_metrics()
	if _native_rollback_planner_bridge != null:
		metrics["rollback_planner"] = _native_rollback_planner_bridge.get_metrics()
	return metrics


func on_checksum_mismatch(server_tick: int, server_snapshot: WorldSnapshot = null) -> bool:
	if predicted_sim_world == null:
		return false
	if server_snapshot != null:
		return on_authoritative_snapshot(server_snapshot)

	var local_snapshot := snapshot_buffer.get_snapshot(server_tick)
	if local_snapshot == null:
		return false

	if predicted_until_tick - server_tick > max_rollback_window:
		_force_resync(local_snapshot)
		return true

	_rollback_from_snapshot(local_snapshot)
	return true


func _rollback_from_snapshot(authoritative_snapshot: WorldSnapshot) -> void:
	if predicted_sim_world == null or snapshot_service == null:
		return

	var replay_to : int = max(predicted_until_tick, authoritative_snapshot.tick_id)
	var replay_count : int = max(0, replay_to - authoritative_snapshot.tick_id)
	if replay_count > MAX_DEFERRED_REPLAY_TICKS:
		_force_resync(authoritative_snapshot)
		return

	rollback_count += 1
	last_rollback_from_tick = authoritative_snapshot.tick_id
	last_replay_tick_count = replay_count
	total_replay_ticks += replay_count
	avg_replay_ticks = ((avg_replay_ticks * float(max(rollback_count - 1, 0))) + replay_count) / float(max(rollback_count, 1))

	var before_positions := _capture_player_positions()
	predicted_sim_world.state.runtime_flags.rollback_mode = true
	snapshot_service.restore_snapshot(predicted_sim_world, authoritative_snapshot)
	if predicted_sim_world.tick_runner != null:
		predicted_sim_world.tick_runner.set_tick(authoritative_snapshot.tick_id)

	while predicted_sim_world.tick_runner != null and predicted_sim_world.tick_runner.current_tick < replay_to:
		var next_tick := predicted_sim_world.tick_runner.current_tick + 1
		_inject_local_inputs_for_tick(next_tick)
		predicted_sim_world.step()
		if snapshot_service != null:
			snapshot_buffer.put(snapshot_service.build_light_snapshot(predicted_sim_world, next_tick))

	predicted_sim_world.state.runtime_flags.rollback_mode = false
	predicted_until_tick = replay_to
	_emit_visual_corrections(before_positions, _capture_player_positions())


func _inject_local_inputs_for_tick(tick_id: int) -> void:
	if predicted_sim_world == null:
		return

	var frame := local_input_buffer.get_frame(tick_id)
	if frame == null:
		frame = _make_idle_local_input(tick_id)

	var slot := _find_local_player_slot()
	if slot < 0:
		return

	var input_frame := InputFrame.new()
	input_frame.tick = tick_id
	input_frame.set_command(slot, _to_player_command(frame))
	predicted_sim_world.enqueue_input(input_frame)


func _force_resync(snapshot: WorldSnapshot) -> void:
	if predicted_sim_world == null or snapshot_service == null or snapshot == null:
		return

	force_resync_count += 1
	last_replay_tick_count = 0
	snapshot_service.restore_snapshot(predicted_sim_world, snapshot)
	if predicted_sim_world.tick_runner != null:
		predicted_sim_world.tick_runner.set_tick(snapshot.tick_id)
	predicted_until_tick = snapshot.tick_id
	snapshot_buffer.put(snapshot)
	full_visual_resync.emit(snapshot)


func _should_force_resync(authoritative_snapshot: WorldSnapshot, local_snapshot: WorldSnapshot) -> bool:
	if authoritative_snapshot == null or local_snapshot == null:
		return true

	if predicted_until_tick - authoritative_snapshot.tick_id > max_rollback_window:
		return true
	if authoritative_snapshot.rng_state != 0 and local_snapshot.rng_state != 0 and authoritative_snapshot.rng_state != local_snapshot.rng_state:
		return true
	if not _has_matching_local_player_entry(authoritative_snapshot.players, local_snapshot.players):
		return true
	if compare_bubbles and authoritative_snapshot.bubbles.size() != local_snapshot.bubbles.size():
		return true
	if compare_items and authoritative_snapshot.items.size() != local_snapshot.items.size():
		return true
	return false


func _plan_rollback(authoritative_snapshot: WorldSnapshot, local_snapshot: WorldSnapshot, diff_result: Dictionary) -> Dictionary:
	if _native_rollback_planner_bridge == null:
		return {}
	var plan: Dictionary = _native_rollback_planner_bridge.plan(
		_build_planner_cursor(authoritative_snapshot, local_snapshot),
		diff_result
	)
	_last_native_planner_metrics = {
		"last_plan": plan,
	}
	return plan


func _build_planner_cursor(authoritative_snapshot: WorldSnapshot, local_snapshot: WorldSnapshot) -> Dictionary:
	return {
		"authoritative_tick": authoritative_snapshot.tick_id if authoritative_snapshot != null else -1,
		"latest_authoritative_tick": -1,
		"predicted_until_tick": predicted_until_tick,
		"max_rollback_window": max_rollback_window,
		"local_snapshot_exists": local_snapshot != null,
		"rng_state_match": authoritative_snapshot != null and local_snapshot != null and authoritative_snapshot.rng_state == local_snapshot.rng_state,
		"force_resync": authoritative_snapshot != null and _should_force_resync(authoritative_snapshot, local_snapshot),
		"compare_bubbles": compare_bubbles,
		"compare_items": compare_items,
	}


func _snapshot_to_diff_dict(snapshot: WorldSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	return {
		"tick": snapshot.tick_id,
		"players": snapshot.players,
		"bubbles": snapshot.bubbles,
		"items": snapshot.items,
		"rng_state": snapshot.rng_state,
	}


func _diff_options() -> Dictionary:
	return {
		"local_peer_id": local_peer_id,
		"compare_bubbles": compare_bubbles,
		"compare_items": compare_items,
		"ignored_local_player_keys": ignored_local_player_keys,
	}


func _has_matching_local_player_entry(left_values: Array[Dictionary], right_values: Array[Dictionary]) -> bool:
	if local_peer_id < 0:
		return left_values.size() == right_values.size()
	var left_entry := _find_local_player_entry(left_values)
	var right_entry := _find_local_player_entry(right_values)
	return not left_entry.is_empty() and not right_entry.is_empty()


func _find_local_player_entry(values: Array[Dictionary]) -> Dictionary:
	for entry in values:
		if int(entry.get("player_slot", -1)) == local_peer_id:
			return entry
	return {}


func _find_local_player_slot() -> int:
	if predicted_sim_world == null:
		return -1

	for player_id in predicted_sim_world.state.players.active_ids:
		var player := predicted_sim_world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.player_slot == local_peer_id:
			return player.player_slot

	return -1


func _make_idle_local_input(tick_id: int) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = local_peer_id
	frame.tick_id = tick_id
	frame.seq = tick_id
	frame.move_x = 0
	frame.move_y = 0
	frame.action_place = false
	frame.action_skill1 = false
	frame.action_skill2 = false
	return frame


func _to_player_command(frame: PlayerInputFrame) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = frame.move_x
	command.move_y = frame.move_y
	command.place_bubble = frame.action_place
	command.remote_trigger = frame.action_skill1 or frame.action_skill2
	command.sequence_id = frame.seq
	return command


func _capture_player_positions() -> Dictionary:
	var positions: Dictionary = {}
	if predicted_sim_world == null:
		return positions

	for player_id in predicted_sim_world.state.players.active_ids:
		var player := predicted_sim_world.state.players.get_player(player_id)
		if player == null:
			continue
		positions[player.entity_id] = GridMotionMath.get_player_abs_pos(player)

	return positions


func _emit_visual_corrections(before_positions: Dictionary, after_positions: Dictionary) -> void:
	for entity_id in after_positions.keys():
		var from_pos: Vector2i = before_positions.get(entity_id, after_positions[entity_id])
		var to_pos: Vector2i = after_positions[entity_id]
		if from_pos != to_pos:
			prediction_corrected.emit(entity_id, from_pos, to_pos)
