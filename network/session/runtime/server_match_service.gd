class_name ServerMatchService
extends Node

const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")

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


func _ready() -> void:
	_ensure_runtime()


func _process(delta: float) -> void:
	if not _active or _authority_runtime == null:
		return
	_tick_accumulator += delta
	while _tick_accumulator >= TickRunnerScript.TICK_DT and _active:
		_tick_accumulator -= TickRunnerScript.TICK_DT
		for message in _authority_runtime.advance_authoritative_tick({}):
			broadcast_message.emit(message)


func start_match(snapshot: RoomSnapshot) -> Dictionary:
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
	if not _authority_runtime.start_match(config):
		return {
			"ok": false,
			"validation": {
				"error_message": "Server failed to start authority runtime",
			},
		}
	_current_config = config.duplicate_deep()
	_active = true
	_tick_accumulator = 0.0
	canonical_config_ready.emit(_current_config)
	for player_entry in _current_config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id <= 0:
			continue
		var peer_config := _current_config.duplicate_deep()
		peer_config.build_mode = BattleStartConfig.BUILD_MODE_CANDIDATE
		peer_config.session_mode = "network_client"
		peer_config.topology = "dedicated_server"
		peer_config.local_peer_id = peer_id
		peer_config.controlled_peer_id = peer_id
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
			"start_config": peer_config.to_dict(),
		})
	return {
		"ok": true,
		"config": _current_config,
		"validation": validation,
	}


func ingest_runtime_message(message: Dictionary) -> void:
	if not _active or _authority_runtime == null:
		return
	_authority_runtime.ingest_network_message(message)


func is_match_active() -> bool:
	return _active and _authority_runtime != null and _authority_runtime.is_match_running()


func abort_match_due_to_disconnect(peer_id: int) -> BattleResult:
	if not is_match_active():
		return null
	var result := BattleResultScript.new()
	var aborted_config := _current_config.duplicate_deep() if _current_config != null else null
	result.finish_reason = "peer_disconnected"
	result.finish_tick = 0
	if _authority_runtime != null and _authority_runtime.server_session != null and _authority_runtime.server_session.active_match != null:
		result.finish_tick = _authority_runtime.server_session.active_match.sim_world.state.match_state.tick
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


func shutdown_match() -> void:
	_active = false
	_tick_accumulator = 0.0
	_current_config = null
	if _authority_runtime != null:
		_authority_runtime.shutdown_runtime()


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
	shutdown_match()
	match_finished.emit(_result)
