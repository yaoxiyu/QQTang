class_name AuthorityRuntime
extends Node

const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")
const TRACE_TAG := "sync.trace"

signal match_started(config: BattleStartConfig)
signal authoritative_tick_completed(tick_result: Dictionary, metrics: Dictionary)
signal battle_finished(result: BattleResult)
signal log_event(message: String)

var start_config: BattleStartConfig = null
var local_peer_id: int = 1
var server_session: ServerSession = null
var _finished: bool = false


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
	match_started.emit(start_config)
	log_event.emit("AuthorityRuntime started %s" % start_config.to_log_string())
	return true


func ingest_network_message(message: Dictionary) -> void:
	if server_session == null:
		return
	var message_type := str(message.get("message_type", message.get("msg_type", "")))
	if message_type != TransportMessageTypesScript.INPUT_FRAME:
		return
	var frame := PlayerInputFrame.from_dict(message.get("frame", {}))
	if frame.peer_id <= 0:
		frame.peer_id = int(message.get("sender_peer_id", 0))
	_retarget_late_place_frame(frame)
	server_session.receive_input(frame)


func advance_authoritative_tick(local_input: Dictionary = {}) -> Array[Dictionary]:
	if server_session == null or server_session.active_match == null or _finished:
		return []

	var next_tick := server_session.active_match.sim_world.state.match_state.tick + 1
	if local_peer_id > 0:
		server_session.receive_input(_build_local_input_frame(next_tick, local_input))
	server_session.tick_once()
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
	if server_session != null and is_instance_valid(server_session):
		server_session.free()
	server_session = null
	start_config = null
	_finished = false


func _build_local_input_frame(tick_id: int, local_input: Dictionary) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = local_peer_id
	frame.tick_id = tick_id
	frame.seq = tick_id
	frame.move_x = clamp(int(local_input.get("move_x", 0)), -1, 1)
	frame.move_y = clamp(int(local_input.get("move_y", 0)), -1, 1)
	frame.action_place = bool(local_input.get("action_place", false))
	frame.sanitize()
	return frame


func _retarget_late_place_frame(frame: PlayerInputFrame) -> void:
	if frame == null or not frame.action_place:
		return
	if server_session == null or server_session.active_match == null or server_session.active_match.sim_world == null:
		return
	var authority_tick := int(server_session.active_match.sim_world.state.match_state.tick)
	if frame.tick_id > authority_tick:
		return
	var original_tick := frame.tick_id
	frame.tick_id = authority_tick + 1
	frame.sanitize()
	LogSyncScript.info(
		"authority_input late_place_retarget peer=%d from_tick=%d to_tick=%d authority_tick=%d" % [
			frame.peer_id,
			original_tick,
			frame.tick_id,
			authority_tick,
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
