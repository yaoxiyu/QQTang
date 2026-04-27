class_name ClientInputBatchBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const BattleWireBudgetProfilerScript = preload("res://network/session/runtime/battle_wire_budget_profiler.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")

const TRACE_TAG := "sync.trace"
const FRAME_FLAG_LATEST := 1 << 0
const FRAME_FLAG_EDGE_ACTION := 1 << 1
const FRAME_FLAG_RESEND := 1 << 2
const FRAME_FLAG_HAS_SEQ := 1 << 3
const INPUT_BATCH_WARN_FRAMES := 10

var _local_peer_id: int = 0
var _controlled_peer_id: int = 0
var _protocol_version: int = 0
var _match_id: String = ""
var _send_seq: int = 0
var _place_redundancy_ticks_remaining: int = 0
var _last_sent_action_bits_by_tick: Dictionary = {}
var _last_metrics: Dictionary = {}
var _profiler: RefCounted = BattleWireBudgetProfilerScript.new()


func configure(local_peer_id: int, controlled_peer_id: int, protocol_version: int, match_id: String) -> void:
	_local_peer_id = local_peer_id
	_controlled_peer_id = controlled_peer_id if controlled_peer_id > 0 else local_peer_id
	_protocol_version = protocol_version
	_match_id = match_id


func resolve_effective_action_bits(
	requested_bits: int,
	next_tick: int,
	resume_coordinator: RefCounted = null,
	predicted_world: SimWorld = null
) -> int:
	var requested_place := (requested_bits & PlayerInputFrame.BIT_PLACE) != 0
	var effective_place := _resolve_redundant_place_action(requested_place, next_tick, resume_coordinator, predicted_world)
	var effective_bits := requested_bits
	if effective_place:
		effective_bits |= PlayerInputFrame.BIT_PLACE
	else:
		effective_bits &= ~PlayerInputFrame.BIT_PLACE
	return effective_bits


func build_batch(client_session: ClientSession, latest_frame: PlayerInputFrame) -> Dictionary:
	if client_session == null or latest_frame == null:
		return {}
	_send_seq += 1
	var ack_tick := int(client_session.last_confirmed_tick)
	var latest_tick := int(latest_frame.tick_id)
	var first_tick := _compute_input_batch_first_tick(ack_tick, latest_tick)
	var candidates: Array[PlayerInputFrame] = []
	for tick in range(first_tick, latest_tick + 1):
		var frame: PlayerInputFrame = client_session.get_network_frame(tick)
		if frame == null:
			continue
		if _should_send_frame(client_session, frame, latest_tick, ack_tick):
			candidates.append(frame)
	candidates = _trim_candidates(candidates, latest_tick)
	var compact_frames := _build_compact_frames(candidates, first_tick, latest_tick, ack_tick)
	var batch := {
		"message_type": TransportMessageTypesScript.INPUT_BATCH,
		"wire_version": BattleWireBudgetContractScript.WIRE_VERSION,
		"protocol_version": _protocol_version,
		"match_id": _match_id,
		"peer_id": _local_peer_id,
		"controlled_peer_id": _controlled_peer_id,
		"client_batch_seq": _send_seq,
		"ack_base_tick": ack_tick,
		"first_tick": first_tick,
		"latest_tick": latest_tick,
		"frame_count": compact_frames.size(),
		"flags": 0,
		"frames": compact_frames,
	}
	_record_input_batch_metrics(batch)
	return batch


func get_metrics() -> Dictionary:
	return _last_metrics.duplicate(true)


func reset() -> void:
	_send_seq = 0
	_place_redundancy_ticks_remaining = 0
	_last_sent_action_bits_by_tick.clear()
	_last_metrics.clear()
	_profiler.reset()


func _compute_input_batch_first_tick(ack_tick: int, latest_tick: int) -> int:
	var first_tick: int = max(0, ack_tick + 1 - BattleWireBudgetContractScript.ACK_SAFETY_MARGIN_TICKS)
	var hard_cap_first_tick: int = latest_tick - BattleWireBudgetContractScript.MAX_INPUT_FRAMES_PER_BATCH + 1
	return max(first_tick, hard_cap_first_tick)


func _should_send_frame(client_session: ClientSession, frame: PlayerInputFrame, latest_tick: int, ack_tick: int) -> bool:
	if frame == null:
		return false
	if int(frame.tick_id) == latest_tick:
		return true
	if int(frame.tick_id) <= ack_tick:
		return false
	if _has_edge_action(frame):
		return true
	var previous_frame: PlayerInputFrame = client_session.get_network_frame(int(frame.tick_id) - 1)
	if _frame_changed(previous_frame, frame):
		return true
	if _is_recent_edge_redundancy(frame, latest_tick):
		return true
	return false


func _trim_candidates(candidates: Array[PlayerInputFrame], latest_tick: int) -> Array[PlayerInputFrame]:
	var trimmed: Array[PlayerInputFrame] = candidates.duplicate()
	trimmed.sort_custom(func(a: PlayerInputFrame, b: PlayerInputFrame) -> bool:
		return int(a.tick_id) < int(b.tick_id)
	)
	while trimmed.size() > BattleWireBudgetContractScript.MAX_INPUT_FRAMES_PER_BATCH:
		var remove_index := 0
		for index in range(trimmed.size()):
			var frame: PlayerInputFrame = trimmed[index]
			if int(frame.tick_id) == latest_tick or _has_edge_action(frame):
				continue
			remove_index = index
			break
		trimmed.remove_at(remove_index)
	return trimmed


func _build_compact_frames(candidates: Array[PlayerInputFrame], first_tick: int, latest_tick: int, ack_tick: int) -> Array:
	var frames: Array = []
	var previous_action_bits := 0
	for frame in candidates:
		var flags := FRAME_FLAG_HAS_SEQ
		if int(frame.tick_id) == latest_tick:
			flags |= FRAME_FLAG_LATEST
		if _has_edge_action(frame):
			flags |= FRAME_FLAG_EDGE_ACTION
		if int(frame.tick_id) <= ack_tick:
			flags |= FRAME_FLAG_RESEND
		var action_bits := int(frame.action_bits)
		if previous_action_bits != action_bits:
			_last_sent_action_bits_by_tick[int(frame.tick_id)] = action_bits
		previous_action_bits = action_bits
		frames.append({
			"tick_delta": int(frame.tick_id) - first_tick,
			"seq": int(frame.seq),
			"move_x": int(frame.move_x),
			"move_y": int(frame.move_y),
			"action_bits": action_bits,
			"flags": flags,
		})
	return frames


func _record_input_batch_metrics(batch: Dictionary) -> void:
	var frame_count := int(batch.get("frame_count", 0))
	var encoded_bytes := var_to_bytes(batch).size()
	_profiler.profile_input_batch(batch, encoded_bytes)
	var previous_budget_warn_count := int(_last_metrics.get("input_batch_budget_warn_count", 0))
	var budget_exceeded := frame_count > INPUT_BATCH_WARN_FRAMES or encoded_bytes > BattleWireBudgetContractScript.INPUT_BATCH_WARN_BYTES
	_last_metrics = {
		"input_batch_frame_count": frame_count,
		"input_batch_encoded_bytes": encoded_bytes,
		"input_batch_first_tick": int(batch.get("first_tick", 0)),
		"input_batch_latest_tick": int(batch.get("latest_tick", 0)),
		"input_batch_ack_base_tick": int(batch.get("ack_base_tick", -1)),
		"input_batch_budget_warn_count": previous_budget_warn_count + (1 if budget_exceeded else 0),
		"max_observed_batch_frame_count": max(int(_last_metrics.get("max_observed_batch_frame_count", 0)), frame_count),
		"max_observed_batch_encoded_bytes": max(int(_last_metrics.get("max_observed_batch_encoded_bytes", 0)), encoded_bytes),
		"input_batch_send_count": _send_seq,
		"input_batch_v2_frame_count": frame_count,
		"input_batch_v2_encoded_bytes": encoded_bytes,
		"input_batch_v2_changed_frame_count": _count_changed_frames(batch),
		"input_batch_v2_edge_frame_count": _count_flagged_frames(batch, FRAME_FLAG_EDGE_ACTION),
		"input_batch_v2_resend_frame_count": _count_flagged_frames(batch, FRAME_FLAG_RESEND),
		"input_batch_v2_budget_exceeded_count": previous_budget_warn_count + (1 if budget_exceeded else 0),
		"battle_wire_budget": _profiler.build_metrics(),
	}
	if budget_exceeded:
		LogSyncScript.warn(
			"QQT_INPUT_BATCH_BUDGET_WARN peer_id=%d frame_count=%d encoded_bytes=%d first_tick=%d latest_tick=%d ack_base_tick=%d" % [
				_local_peer_id,
				frame_count,
				encoded_bytes,
				int(batch.get("first_tick", 0)),
				int(batch.get("latest_tick", 0)),
				int(batch.get("ack_base_tick", -1)),
			],
			"",
			0,
			"%s sync.client_input_batch_builder" % TRACE_TAG
		)


func _resolve_redundant_place_action(
	requested_place: bool,
	local_tick: int,
	resume_coordinator: RefCounted,
	predicted_world: SimWorld
) -> bool:
	if _resolve_local_place_action(requested_place, local_tick, resume_coordinator, predicted_world):
		_place_redundancy_ticks_remaining = BattleWireBudgetContractScript.EDGE_ACTION_REDUNDANCY_TICKS
	if _place_redundancy_ticks_remaining <= 0:
		return false
	_place_redundancy_ticks_remaining -= 1
	return true


func _resolve_local_place_action(
	requested_place: bool,
	local_tick: int,
	resume_coordinator: RefCounted,
	predicted_world: SimWorld
) -> bool:
	if resume_coordinator != null and resume_coordinator.has_method("resolve_local_place_action"):
		return bool(resume_coordinator.call("resolve_local_place_action", requested_place, local_tick, predicted_world))
	return requested_place


func _frame_changed(previous_frame: PlayerInputFrame, frame: PlayerInputFrame) -> bool:
	if frame == null:
		return false
	if previous_frame == null:
		return true
	return int(previous_frame.move_x) != int(frame.move_x) \
		or int(previous_frame.move_y) != int(frame.move_y) \
		or int(previous_frame.action_bits) != int(frame.action_bits)


func _has_edge_action(frame: PlayerInputFrame) -> bool:
	return frame != null and int(frame.action_bits) != 0


func _is_recent_edge_redundancy(frame: PlayerInputFrame, latest_tick: int) -> bool:
	if frame == null or int(frame.action_bits) == 0:
		return false
	return latest_tick - int(frame.tick_id) < BattleWireBudgetContractScript.EDGE_ACTION_REDUNDANCY_TICKS


func _count_flagged_frames(batch: Dictionary, flag: int) -> int:
	var count := 0
	var frames: Array = batch.get("frames", []) if batch.get("frames", []) is Array else []
	for frame in frames:
		if frame is Dictionary and (int((frame as Dictionary).get("flags", 0)) & flag) != 0:
			count += 1
	return count


func _count_changed_frames(batch: Dictionary) -> int:
	var frames: Array = batch.get("frames", []) if batch.get("frames", []) is Array else []
	var count := 0
	var previous_key := ""
	for frame in frames:
		if not (frame is Dictionary):
			continue
		var key := "%d:%d:%d" % [
			int((frame as Dictionary).get("move_x", 0)),
			int((frame as Dictionary).get("move_y", 0)),
			int((frame as Dictionary).get("action_bits", 0)),
		]
		if key != previous_key:
			count += 1
		previous_key = key
	return count
