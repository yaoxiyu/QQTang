class_name AuthorityRuntime
extends Node

const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const NativeInputBufferBridgeScript = preload("res://gameplay/native_bridge/native_input_buffer_bridge.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const RuntimeShutdownContextScript = preload("res://app/runtime/runtime_shutdown_context.gd")
const TRACE_TAG := "sync.trace"

signal match_started(config: BattleStartConfig)
signal authoritative_tick_completed(tick_result: Dictionary, metrics: Dictionary)
signal battle_finished(result: BattleResult)
signal log_event(message: String)

var start_config: BattleStartConfig = null
var local_peer_id: int = 1
var server_session: ServerSession = null
var _finished: bool = false

var _opening_input_freeze_drop_count: int = 0
var _opening_input_freeze_end_logged: bool = false
var _native_input_policy: RefCounted = NativeInputBufferBridgeScript.new()
var _native_input_policy_metrics: Dictionary = {}
var invalid_batch_drop_count: int = 0


func configure(peer_id: int) -> void:
	local_peer_id = peer_id


func start_match(config: BattleStartConfig) -> bool:
	shutdown_runtime()
	if config == null:
		return false

	start_config = config.duplicate_deep()
	server_session = ServerSession.new()
	add_child(server_session)
	server_session.create_room(start_config.room_id, start_config.map_id, start_config.rule_set_id)
	for player_entry in start_config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id <= 0:
			continue
		server_session.add_peer(peer_id)
		server_session.set_peer_ready(peer_id, true)

	var sim_config := BattleSimConfigBuilderScript.new().build_for_start_config(start_config)
	var started := server_session.start_match(
		sim_config,
		{
			"grid": MapLoaderScript.build_grid_state(start_config.map_id),
			"player_slots": start_config.player_slots.duplicate(true),
			"spawn_assignments": start_config.spawn_assignments.duplicate(true),
		},
		start_config.battle_seed,
		start_config.start_tick
	)
	if not started or server_session.active_match == null:
		log_event.emit("AuthorityRuntime failed to start match")
		shutdown_runtime()
		return false

	server_session.active_match.match_id = start_config.match_id
	server_session.active_match.sim_world.state.match_state.remaining_ticks = int(start_config.match_duration_ticks)
	server_session.active_match.sim_world.state.match_state.phase = MatchState.Phase.PLAYING
	_finished = false
	_opening_input_freeze_drop_count = 0
	_opening_input_freeze_end_logged = false
	_native_input_policy = NativeInputBufferBridgeScript.new()
	_native_input_policy.configure(8, 64, 4, false)
	_native_input_policy_metrics.clear()
	match_started.emit(start_config)
	log_event.emit("AuthorityRuntime started %s" % start_config.to_log_string())
	return true


func ingest_network_message(message: Dictionary) -> void:
	if server_session == null:
		return
	var message_type := str(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.INPUT_BATCH:
		_ingest_input_batch(message)
		return


func _ingest_input_batch(message: Dictionary) -> void:
	if not _validate_input_batch_envelope(message):
		invalid_batch_drop_count += 1
		return
	var frames: Variant = message.get("frames", [])
	if not (frames is Array):
		return
	var batch_peer_id := int(message.get("peer_id", 0))
	var first_tick := int(message.get("first_tick", 0))
	var latest_tick := int(message.get("latest_tick", 0))
	for frame_data in frames:
		if not (frame_data is Dictionary):
			continue
		var frame_tick_id := first_tick + int((frame_data as Dictionary).get("tick_delta", -1))
		if frame_tick_id < first_tick or frame_tick_id > latest_tick:
			continue
		var frame := PlayerInputFrame.new()
		frame.peer_id = batch_peer_id
		frame.tick_id = frame_tick_id
		frame.seq = int((frame_data as Dictionary).get("seq", frame_tick_id))
		frame.move_x = int((frame_data as Dictionary).get("move_x", 0))
		frame.move_y = int((frame_data as Dictionary).get("move_y", 0))
		frame.action_bits = int((frame_data as Dictionary).get("action_bits", 0))
		frame.sanitize()
		_submit_input_frame(frame)


func _validate_input_batch_envelope(message: Dictionary) -> bool:
	if int(message.get("wire_version", 0)) != BattleWireBudgetContractScript.WIRE_VERSION:
		return false
	if String(message.get("message_type", "")) != TransportMessageTypesScript.INPUT_BATCH:
		return false
	var peer_id := int(message.get("peer_id", 0))
	if peer_id <= 0:
		return false
	var frames: Variant = message.get("frames", [])
	if not (frames is Array):
		return false
	var frame_count := int(message.get("frame_count", -1))
	if frame_count != (frames as Array).size():
		return false
	var first_tick := int(message.get("first_tick", 0))
	var latest_tick := int(message.get("latest_tick", 0))
	if first_tick > latest_tick:
		return false
	if frame_count > BattleWireBudgetContractScript.MAX_INPUT_FRAMES_PER_BATCH:
		return false
	for frame_data in frames:
		if not (frame_data is Dictionary):
			return false
		var frame := frame_data as Dictionary
		if not frame.has("tick_delta") or not frame.has("move_x") or not frame.has("move_y") or not frame.has("action_bits"):
			return false
		var tick_id := first_tick + int(frame.get("tick_delta", -1))
		if tick_id < first_tick or tick_id > latest_tick:
			return false
	return true


func _submit_input_frame(frame: PlayerInputFrame) -> void:
	if frame == null:
		return
	if _is_opening_input_frozen():
		_opening_input_freeze_drop_count += 1
		return
	var authority_tick := _get_authority_tick()
	var native_decision := _evaluate_native_input_policy(frame, authority_tick)
	if native_decision.is_empty() or String(native_decision.get("status", "")).begins_with("drop_"):
		return
	if bool(native_decision.get("retargeted", false)):
		frame.tick_id = int(native_decision.get("tick_id", frame.tick_id))
		frame.sanitize()
	server_session.receive_input(frame)


func advance_authoritative_tick(local_input: Dictionary = {}) -> Array[Dictionary]:
	if server_session == null or server_session.active_match == null or _finished:
		return []

	var next_tick := server_session.active_match.sim_world.state.match_state.tick + 1
	if local_peer_id > 0 and not _is_opening_input_frozen():
		server_session.receive_input(_build_local_input_frame(next_tick, local_input))
	server_session.tick_once()
	_log_opening_input_freeze_end_if_needed()
	var outgoing := _decorate_messages(server_session.poll_messages())

	var sim_world := server_session.active_match.sim_world
	var tick_result := {
		"tick": sim_world.state.match_state.tick,
		"events": sim_world.events.get_events(),
		"phase": sim_world.state.match_state.phase,
	}
	var metrics := {
		"authoritative_tick": sim_world.state.match_state.tick,
		"remaining_ticks": sim_world.state.match_state.remaining_ticks,
		"player_count": start_config.player_slots.size() if start_config != null else 0,
		"native_input_policy": get_native_input_policy_metrics(),
	}
	authoritative_tick_completed.emit(tick_result, metrics)

	if int(sim_world.state.match_state.phase) == MatchState.Phase.ENDED:
		_finished = true
		var result := BattleResult.from_authoritative_state(sim_world, start_config, local_peer_id)
		outgoing.append(_decorate_message({
			"message_type": TransportMessageTypesScript.MATCH_FINISHED,
			"result": result.to_dict(),
			"tick": result.finish_tick,
		}))
		battle_finished.emit(result)

	return outgoing


func poll_opening_messages() -> Array[Dictionary]:
	if server_session == null:
		return []
	return _decorate_messages(server_session.poll_messages())


func is_match_running() -> bool:
	return server_session != null and server_session.active_match != null and not _finished


func shutdown_runtime() -> void:
	shutdown(RuntimeShutdownContextScript.new("authority_runtime_shutdown", false))


func get_shutdown_name() -> String:
	return "authority_runtime"


func get_shutdown_priority() -> int:
	return 60


func shutdown(_context: Variant) -> void:
	if server_session != null and is_instance_valid(server_session):
		if server_session.has_method("shutdown_runtime"):
			server_session.shutdown_runtime()
		server_session.free()
	server_session = null
	start_config = null
	_finished = false
	_opening_input_freeze_drop_count = 0
	_opening_input_freeze_end_logged = false
	_native_input_policy = NativeInputBufferBridgeScript.new()
	_native_input_policy_metrics.clear()


func get_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"has_server_session": server_session != null,
		"finished": _finished,
	}


func _build_local_input_frame(tick_id: int, local_input: Dictionary) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = local_peer_id
	frame.tick_id = tick_id
	frame.seq = tick_id
	frame.move_x = clamp(int(local_input.get("move_x", 0)), -1, 1)
	frame.move_y = clamp(int(local_input.get("move_y", 0)), -1, 1)
	frame.action_bits = int(local_input.get("action_bits", 0))
	frame.sanitize()
	return frame


func _get_authority_tick() -> int:
	if server_session == null or server_session.active_match == null or server_session.active_match.sim_world == null:
		return -1
	return int(server_session.active_match.sim_world.state.match_state.tick)


func _evaluate_native_input_policy(frame: PlayerInputFrame, authority_tick: int) -> Dictionary:
	if frame == null:
		return {}
	if _native_input_policy == null:
		_native_input_policy = NativeInputBufferBridgeScript.new()
		_native_input_policy.configure(8, 64, 4, false)
	var decision: Dictionary = _native_input_policy.push_input_dict(frame.to_dict(), authority_tick)
	_native_input_policy_metrics["last_status"] = String(decision.get("status", ""))
	_native_input_policy_metrics["last_retargeted"] = bool(decision.get("retargeted", false))
	_native_input_policy_metrics["last_tick_id"] = int(decision.get("tick_id", frame.tick_id))
	_native_input_policy_metrics["native_buffer_metrics"] = _native_input_policy.get_metrics()
	return decision


func get_native_input_policy_metrics() -> Dictionary:
	return _native_input_policy_metrics.duplicate(true)


func _is_opening_input_frozen() -> bool:
	if start_config == null or server_session == null or server_session.active_match == null:
		return false
	var freeze_ticks := int(start_config.opening_input_freeze_ticks)
	if freeze_ticks <= 0:
		return false
	var authority_tick := int(server_session.active_match.sim_world.state.match_state.tick)
	return authority_tick < int(start_config.start_tick) + freeze_ticks


func _log_opening_input_freeze_end_if_needed() -> void:
	if _opening_input_freeze_end_logged:
		return
	if start_config == null or server_session == null or server_session.active_match == null:
		return
	var freeze_ticks := int(start_config.opening_input_freeze_ticks)
	if freeze_ticks <= 0:
		_opening_input_freeze_end_logged = true
		return
	var authority_tick := int(server_session.active_match.sim_world.state.match_state.tick)
	var end_tick := int(start_config.start_tick) + freeze_ticks
	if authority_tick < end_tick:
		return
	_opening_input_freeze_end_logged = true
	LogSyncScript.info(
		"authority_opening_input_freeze_end tick=%d dropped_inputs=%d" % [
			authority_tick,
			_opening_input_freeze_drop_count,
		],
		"",
		0,
		"%s sync.authority_runtime" % TRACE_TAG
	)


func _decorate_messages(messages: Array) -> Array[Dictionary]:
	var decorated: Array[Dictionary] = []
	for message in messages:
		decorated.append(_decorate_message(message))
	return decorated


func _decorate_message(message: Dictionary) -> Dictionary:
	var decorated := message.duplicate(true)
	decorated["message_type"] = str(decorated.get("message_type", decorated.get("msg_type", "")))
	decorated["msg_type"] = decorated["message_type"]
	decorated["protocol_version"] = int(start_config.protocol_version) if start_config != null else 1
	decorated["match_id"] = String(start_config.match_id) if start_config != null else ""
	decorated["sender_peer_id"] = local_peer_id
	return decorated
