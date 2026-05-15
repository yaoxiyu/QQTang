class_name ServerMatchService
extends Node

const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const AuthorityFrameMessageMergerScript = preload("res://network/session/runtime/authority_frame_message_merger.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")

const MAX_AUTHORITY_TICKS_PER_FRAME := 3
const MAX_ACCUMULATOR_TICKS := 4
const HARD_BACKLOG_TICKS := 16
const OPENING_READY_TIMEOUT_MSEC := 3000
const PHASE_IDLE := 0
const PHASE_OPENING_SENT := 1
const PHASE_WAITING_READY := 2
const PHASE_RUNNING := 3
const PHASE_FINISHING := 4
const PHASE_CLOSED := 5

@warning_ignore("unused_signal")
signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)
signal canonical_config_ready(config: BattleStartConfig)
signal match_finished(result: BattleResult)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9000
var server_match_revision: int = 0

var _coordinator: Node = null
var _authority_runtime: AuthorityRuntime = null
var _tick_accumulator: float = 0.0
var _active: bool = false
var _current_config: BattleStartConfig = null
var _last_finished_result: BattleResult = null
var _last_finished_config: BattleStartConfig = null
var _last_finished_match_id: String = ""
var _last_finished_room_id: String = ""
var _skip_first_active_delta: bool = false
var _frame_message_merger: RefCounted = AuthorityFrameMessageMergerScript.new()
var _server_tick_overflow_count: int = 0
var _last_ticks_this_process: int = 0
var _last_raw_message_count: int = 0
var _last_merged_message_count: int = 0
var _phase: int = PHASE_IDLE
var _ready_peer_ids: Dictionary = {}
var _required_peer_ids: Array[int] = []
var _opening_started_msec: int = 0


func _ready() -> void:
	_ensure_runtime()


func _process(delta: float) -> void:
	if _phase == PHASE_WAITING_READY:
		if _all_required_peers_ready() or Time.get_ticks_msec() - _opening_started_msec >= OPENING_READY_TIMEOUT_MSEC:
			_start_running_ticks()
		return
	if not _active or _authority_runtime == null:
		return
	if _skip_first_active_delta:
		_skip_first_active_delta = false
		delta = 0.0

	_tick_accumulator += maxf(delta, 0.0)
	var backlog_ticks := int(floor(_tick_accumulator / TickRunnerScript.TICK_DT))
	if backlog_ticks > HARD_BACKLOG_TICKS:
		_server_tick_overflow_count += 1
		_tick_accumulator = TickRunnerScript.TICK_DT * float(MAX_ACCUMULATOR_TICKS)
		backlog_ticks = MAX_ACCUMULATOR_TICKS
	else:
		var max_accumulator := TickRunnerScript.TICK_DT * float(MAX_ACCUMULATOR_TICKS)
		_tick_accumulator = min(_tick_accumulator, max_accumulator)
		backlog_ticks = int(floor(_tick_accumulator / TickRunnerScript.TICK_DT))

	var ticks_this_frame: int = min(backlog_ticks, MAX_AUTHORITY_TICKS_PER_FRAME)
	var raw_messages: Array[Dictionary] = []
	for _i in range(ticks_this_frame):
		if not _active:
			break
		_tick_accumulator -= TickRunnerScript.TICK_DT
		raw_messages.append_array(_authority_runtime.advance_authoritative_tick({}))

	_last_ticks_this_process = ticks_this_frame
	_last_raw_message_count = raw_messages.size()
	if raw_messages.is_empty():
		_last_merged_message_count = 0
		return

	var merged_messages: Array[Dictionary] = _frame_message_merger.merge_server_frame(raw_messages)
	_last_merged_message_count = merged_messages.size()
	for message in merged_messages:
		broadcast_message.emit(message)


func start_match(snapshot: RoomSnapshot) -> Dictionary:
	var prepare_result := prepare_match(snapshot)
	if not bool(prepare_result.get("ok", false)):
		return prepare_result
	return commit_prepared_match(prepare_result.get("config"))


func prepare_match(snapshot: RoomSnapshot) -> Dictionary:
	_ensure_runtime()
	if _coordinator == null or not _coordinator.has_method("can_build_from_room") or not _coordinator.can_build_from_room(snapshot):
		return {
			"ok": false,
			"validation": {
				"error_message": "Server room state is not ready to build battle start config",
			},
		}
	server_match_revision += 1
	var config: BattleStartConfig = _coordinator.build_server_canonical_config(
		snapshot,
		authority_host,
		authority_port,
		server_match_revision
	)
	var validation: Dictionary = _coordinator.validate_start_config(config)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"validation": validation,
		}
	return {
		"ok": true,
		"config": config,
		"validation": validation,
	}


func commit_prepared_match(config: BattleStartConfig) -> Dictionary:
	if config == null:
		return {
			"ok": false,
			"validation": {
				"error_message": "Config is null, cannot commit",
			},
		}
	if not _authority_runtime.start_match(config):
		return {
			"ok": false,
			"validation": {
				"error_message": "Server failed to start authority runtime",
			},
		}
	_current_config = config.duplicate_deep()
	_active = false
	_phase = PHASE_OPENING_SENT
	_tick_accumulator = 0.0
	_skip_first_active_delta = true
	_ready_peer_ids.clear()
	_required_peer_ids = _extract_required_peer_ids(_current_config)
	_opening_started_msec = Time.get_ticks_msec()
	canonical_config_ready.emit(_current_config)
	_broadcast_opening_authority_state()
	_phase = PHASE_WAITING_READY
	return {
		"ok": true,
		"config": _current_config,
	}


func build_peer_candidate_config(config: BattleStartConfig, peer_id: int) -> BattleStartConfig:
	var peer_config := config.duplicate_deep()
	peer_config.build_mode = BattleStartConfig.BUILD_MODE_CANDIDATE
	peer_config.session_mode = "network_client"
	peer_config.topology = "dedicated_server"
	peer_config.local_peer_id = peer_id
	peer_config.controlled_peer_id = peer_id
	return peer_config


func ingest_runtime_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.OPENING_SNAPSHOT_ACK or message_type == TransportMessageTypesScript.BATTLE_READY:
		_mark_peer_ready(int(message.get("sender_peer_id", message.get("peer_id", 0))))
		return
	if not _active or _authority_runtime == null:
		return
	_authority_runtime.ingest_network_message(message)


func is_match_active() -> bool:
	return _active and _authority_runtime != null and _authority_runtime.is_match_running()


# LegacyMigration: Get current config for resume
func get_current_config() -> BattleStartConfig:
	return _current_config.duplicate_deep() if _current_config != null else null


func get_last_finished_result() -> BattleResult:
	return _last_finished_result.duplicate_deep() if _last_finished_result != null else null


func get_last_finished_config() -> BattleStartConfig:
	return _last_finished_config.duplicate_deep() if _last_finished_config != null else null


func get_last_finished_match_id() -> String:
	return _last_finished_match_id


func get_last_finished_room_id() -> String:
	return _last_finished_room_id


func get_tick_budget_metrics() -> Dictionary:
	return {
		"ticks_this_process": _last_ticks_this_process,
		"raw_message_count": _last_raw_message_count,
		"merged_message_count": _last_merged_message_count,
		"accumulator_sec": _tick_accumulator,
		"overflow_count": _server_tick_overflow_count,
		"phase": _phase,
	}


# LegacyMigration: Build resume checkpoint message
func build_resume_checkpoint_message() -> Dictionary:
	if _authority_runtime == null or _authority_runtime.server_session == null or _authority_runtime.server_session.active_match == null:
		return {}
	
	var active_match: BattleMatch = _authority_runtime.server_session.active_match
	var tick_id: int = int(active_match.sim_world.state.match_state.tick)
	var snapshot: WorldSnapshot = active_match.borrow_last_authoritative_snapshot()
	if snapshot == null or snapshot.tick_id != tick_id:
		snapshot = active_match.get_snapshot(tick_id)
	if snapshot == null:
		snapshot = active_match.snapshot_service.build_standard_snapshot(active_match.sim_world, tick_id, false)
		snapshot.checksum = active_match.compute_checksum(tick_id)
	
	return {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"msg_type": TransportMessageTypesScript.CHECKPOINT,
		"protocol_version": int(_current_config.protocol_version) if _current_config != null else 1,
		"match_id": String(_current_config.match_id) if _current_config != null else "",
		"sender_peer_id": 1,
		"tick": snapshot.tick_id,
		"players": snapshot.players.duplicate(true),
		"player_summary": active_match.build_player_position_summary(),
		"bubbles": snapshot.bubbles.duplicate(true),
		"items": snapshot.items.duplicate(true),
		"walls": snapshot.walls.duplicate(true),
		"match_state": snapshot.match_state.duplicate(true),
		"mode_state": snapshot.mode_state.duplicate(true),
		"rng_state": snapshot.rng_state,
		"checksum": snapshot.checksum,
	}


func _broadcast_opening_authority_state() -> void:
	if _authority_runtime == null:
		return
	if _authority_runtime.has_method("poll_opening_messages"):
		var opening_msgs: Array = _authority_runtime.poll_opening_messages()
		for message in opening_msgs:
			LogNetScript.info("battle_ds broadcast_opening type=%s tick=%d" % [String(message.get("msg_type", message.get("message_type", ""))), int(message.get("start_tick", message.get("tick", 0)))], "", 0, "net.battle_ds_bootstrap")
			broadcast_message.emit(message)
	var checkpoint := build_resume_checkpoint_message()
	if not checkpoint.is_empty():
		LogNetScript.info("battle_ds broadcast_checkpoint tick=%d" % int(checkpoint.get("tick", 0)), "", 0, "net.battle_ds_bootstrap")
		broadcast_message.emit(checkpoint)


func abort_match_due_to_disconnect(peer_id: int) -> BattleResult:
	if not is_match_active():
		return null
	var result := BattleResultScript.new()
	var aborted_config := _current_config.duplicate_deep() if _current_config != null else null
	result.finish_reason = "peer_disconnected"
	result.finish_tick = 0
	if _authority_runtime != null and _authority_runtime.server_session != null and _authority_runtime.server_session.active_match != null:
		result.finish_tick = _authority_runtime.server_session.active_match.sim_world.state.match_state.tick
	_cache_finished_payload(result)
	shutdown_match()
	broadcast_message.emit({
		"message_type": TransportMessageTypesScript.MATCH_FINISHED,
		"msg_type": TransportMessageTypesScript.MATCH_FINISHED,
		"protocol_version": int(aborted_config.protocol_version) if aborted_config != null else 1,
		"match_id": String(aborted_config.match_id) if aborted_config != null else "",
		"sender_peer_id": 1,
		"tick": result.finish_tick,
		"result": result.to_dict(),
		"disconnect_peer_id": peer_id,
	})
	match_finished.emit(result)
	return result


# LegacyMigration: Abort match due to resume timeout
func abort_match_due_to_resume_timeout(member_id: String) -> BattleResult:
	if not is_match_active():
		return null
	var result := BattleResultScript.new()
	var aborted_config := _current_config.duplicate_deep() if _current_config != null else null
	result.finish_reason = "peer_resume_timeout"
	result.finish_tick = 0
	if _authority_runtime != null and _authority_runtime.server_session != null and _authority_runtime.server_session.active_match != null:
		result.finish_tick = _authority_runtime.server_session.active_match.sim_world.state.match_state.tick
	_cache_finished_payload(result)
	shutdown_match()
	broadcast_message.emit({
		"message_type": TransportMessageTypesScript.MATCH_FINISHED,
		"msg_type": TransportMessageTypesScript.MATCH_FINISHED,
		"protocol_version": int(aborted_config.protocol_version) if aborted_config != null else 1,
		"match_id": String(aborted_config.match_id) if aborted_config != null else "",
		"sender_peer_id": 1,
		"tick": result.finish_tick,
		"result": result.to_dict(),
		"resume_timeout_member_id": member_id,
	})
	match_finished.emit(result)
	return result


func shutdown_match() -> void:
	_active = false
	_phase = PHASE_CLOSED
	_tick_accumulator = 0.0
	_skip_first_active_delta = false
	_ready_peer_ids.clear()
	_required_peer_ids.clear()
	_current_config = null
	if _authority_runtime != null:
		_authority_runtime.shutdown_runtime()


func _cache_finished_payload(result: BattleResult) -> void:
	_last_finished_result = result.duplicate_deep() if result != null else null
	_last_finished_config = _current_config.duplicate_deep() if _current_config != null else null
	_last_finished_match_id = String(_current_config.match_id) if _current_config != null else ""
	_last_finished_room_id = String(_current_config.room_id) if _current_config != null else ""


func _extract_required_peer_ids(config: BattleStartConfig) -> Array[int]:
	var result: Array[int] = []
	if config == null:
		return result
	for player_entry in config.player_slots:
		var peer_id := int(player_entry.get("peer_id", 0))
		if peer_id > 0 and not result.has(peer_id):
			result.append(peer_id)
	result.sort()
	return result


func _mark_peer_ready(peer_id: int) -> void:
	if peer_id <= 0:
		return
	_ready_peer_ids[peer_id] = true


func _all_required_peers_ready() -> bool:
	if _required_peer_ids.is_empty():
		return true
	for peer_id in _required_peer_ids:
		if not bool(_ready_peer_ids.get(peer_id, false)):
			return false
	return true


func _start_running_ticks() -> void:
	if _authority_runtime == null:
		return
	_phase = PHASE_RUNNING
	_active = true
	_tick_accumulator = 0.0
	_skip_first_active_delta = true


func _ensure_runtime() -> void:
	if _coordinator == null:
		_coordinator = MatchStartCoordinatorScript.new()
		add_child(_coordinator)
	if _authority_runtime == null:
		_authority_runtime = AuthorityRuntimeScript.new()
		_authority_runtime.configure(0)
		add_child(_authority_runtime)
		if not _authority_runtime.battle_finished.is_connected(_on_battle_finished):
			_authority_runtime.battle_finished.connect(_on_battle_finished)


func _on_battle_finished(_result: BattleResult) -> void:
	_cache_finished_payload(_result)
	shutdown_match()
	match_finished.emit(_result)
