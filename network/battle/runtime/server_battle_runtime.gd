class_name ServerBattleRuntime
extends Node

## Phase23: Battle-only runtime. Extracted from ServerRoomRuntime.
## Handles match service, loading coordinator, finalize reporter,
## resume coordinator. Does NOT handle room create/join/leave/directory
## or party queue.

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const ServerMatchLoadingCoordinatorScript = preload("res://network/session/runtime/server_match_loading_coordinator.gd")
const ServerMatchFinalizeReporterScript = preload("res://network/session/runtime/server_match_finalize_reporter.gd")
const ServerMatchResumeCoordinatorScript = preload("res://network/session/runtime/server_match_resume_coordinator.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)
signal match_finished(result: BattleResult)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9000

var _match_service: ServerMatchService = null
var _loading_coordinator: ServerMatchLoadingCoordinator = null
var _match_finalize_reporter: ServerMatchFinalizeReporter = null
var _resume_coordinator: ServerMatchResumeCoordinator = null

## Phase23: Battle manifest fields injected by bootstrap
var battle_id: String = ""
var assignment_id: String = ""
var match_id: String = ""

## Phase23: Member bindings for input validation (injected from manifest)
var _member_bindings: Dictionary = {}  # member_id -> { match_peer_id, transport_peer_id, connection_state }


func _ready() -> void:
	_ensure_services()


func _process(_delta: float) -> void:
	if _resume_coordinator != null:
		_resume_coordinator.poll_expired()


func configure(next_authority_host: String, next_authority_port: int) -> void:
	authority_host = next_authority_host if not next_authority_host.strip_edges().is_empty() else "127.0.0.1"
	authority_port = next_authority_port if next_authority_port > 0 else 9000
	_ensure_services()
	if _match_service != null:
		_match_service.authority_host = authority_host
		_match_service.authority_port = authority_port


func handle_battle_message(message: Dictionary) -> void:
	_ensure_services()
	if _match_service == null:
		return
	_match_service.ingest_runtime_message(message)


func handle_loading_message(message: Dictionary) -> void:
	_ensure_services()
	if _loading_coordinator == null:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.MATCH_LOADING_READY:
		var peer_id := int(message.get("sender_peer_id", 0))
		var msg_match_id := String(message.get("match_id", ""))
		var revision := int(message.get("revision", 0))
		_loading_coordinator.mark_peer_ready(peer_id, msg_match_id, revision)


func handle_peer_disconnected(peer_id: int) -> void:
	_ensure_services()

	# Loading phase disconnect - abort immediately
	if _loading_coordinator != null and _loading_coordinator.is_loading_active():
		_loading_coordinator.handle_peer_disconnected(peer_id)
		return

	# Active match disconnect - enter resume window
	if _match_service != null and _match_service.is_match_active():
		var member_id := _find_member_id_by_transport_peer(peer_id)
		if not member_id.is_empty() and _resume_coordinator != null:
			_resume_coordinator.on_member_disconnected(member_id)
			return


func begin_loading(snapshot: RoomSnapshot) -> Dictionary:
	_ensure_services()
	if _loading_coordinator == null:
		return {"ok": false, "user_message": "Loading coordinator not available"}
	var result: Dictionary = _loading_coordinator.begin_loading(snapshot)
	if not bool(result.get("ok", false)):
		_emit_broadcast_message({
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"user_message": String(result.get("user_message", "Server failed to start match")),
		})
	return result


func is_match_active() -> bool:
	_ensure_services()
	return _match_service != null and _match_service.is_match_active()


func is_loading_active() -> bool:
	return _loading_coordinator != null and _loading_coordinator.is_loading_active()


func get_match_service() -> ServerMatchService:
	_ensure_services()
	return _match_service


func report_match_result(result: BattleResult) -> void:
	if _match_finalize_reporter != null and _match_finalize_reporter.has_method("report_match_result_async"):
		_match_finalize_reporter.report_match_result_async(self, result)


func set_member_bindings(bindings: Dictionary) -> void:
	_member_bindings = bindings


func _find_member_id_by_transport_peer(peer_id: int) -> String:
	for member_id in _member_bindings.keys():
		var info: Dictionary = _member_bindings.get(member_id, {})
		if int(info.get("transport_peer_id", 0)) == peer_id:
			return String(member_id)
	return ""


func _ensure_services() -> void:
	if _match_service == null:
		_match_service = ServerMatchServiceScript.new()
		_match_service.name = "ServerMatchService"
		add_child(_match_service)
		_connect_match_service_signals()
	if _loading_coordinator == null:
		_loading_coordinator = ServerMatchLoadingCoordinatorScript.new()
		_loading_coordinator.configure(
			_prepare_match_callable(),
			_commit_match_callable(),
			_send_to_peer_callable(),
			_broadcast_message_callable(),
			_loading_started_callable(),
			_loading_aborted_callable(),
			_loading_committed_callable()
		)
	if _resume_coordinator == null:
		_resume_coordinator = ServerMatchResumeCoordinatorScript.new()
		_resume_coordinator.name = "ServerMatchResumeCoordinator"
		add_child(_resume_coordinator)
		_connect_resume_coordinator_signals()
	if _match_finalize_reporter == null:
		_match_finalize_reporter = ServerMatchFinalizeReporterScript.new()
		_match_finalize_reporter.configure()
	if _match_service != null:
		_match_service.authority_host = authority_host
		_match_service.authority_port = authority_port


func _connect_match_service_signals() -> void:
	if _match_service == null:
		return
	if not _match_service.send_to_peer.is_connected(_emit_send_to_peer):
		_match_service.send_to_peer.connect(_emit_send_to_peer)
	if not _match_service.broadcast_message.is_connected(_emit_match_broadcast_message):
		_match_service.broadcast_message.connect(_emit_match_broadcast_message)
	if not _match_service.match_finished.is_connected(_on_match_finished):
		_match_service.match_finished.connect(_on_match_finished)


func _connect_resume_coordinator_signals() -> void:
	if _resume_coordinator == null:
		return
	if not _resume_coordinator.send_to_peer.is_connected(_emit_send_to_peer):
		_resume_coordinator.send_to_peer.connect(_emit_send_to_peer)
	if not _resume_coordinator.match_abort_requested.is_connected(_on_match_resume_timeout_abort_requested):
		_resume_coordinator.match_abort_requested.connect(_on_match_resume_timeout_abort_requested)


func _on_match_finished(result: BattleResult) -> void:
	_log("match_finished", {"battle_id": battle_id, "assignment_id": assignment_id})
	match_finished.emit(result)
	report_match_result(result)
	if _resume_coordinator != null:
		_resume_coordinator.clear_match_state()


func _on_match_resume_timeout_abort_requested(reason: String, member_id: String) -> void:
	if _match_service != null and _match_service.is_match_active():
		_match_service.abort_match_due_to_resume_timeout(member_id)


func _emit_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _emit_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _emit_match_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _prepare_match_callable() -> Callable:
	return Callable(self, "_do_prepare_match")

func _commit_match_callable() -> Callable:
	return Callable(self, "_do_commit_match")

func _send_to_peer_callable() -> Callable:
	return Callable(self, "_do_send_to_peer")

func _broadcast_message_callable() -> Callable:
	return Callable(self, "_do_broadcast_message")

func _loading_started_callable() -> Callable:
	return Callable(self, "_on_loading_started")

func _loading_aborted_callable() -> Callable:
	return Callable(self, "_on_loading_aborted")

func _loading_committed_callable() -> Callable:
	return Callable(self, "_on_loading_committed")


func _do_prepare_match(snapshot: RoomSnapshot) -> Dictionary:
	if _match_service == null:
		_ensure_services()
	return _match_service.prepare_match(snapshot)


func _do_commit_match(config: BattleStartConfig) -> Dictionary:
	if _match_service == null:
		_ensure_services()
	return _match_service.commit_prepared_match(config)


func _do_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _do_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _on_loading_started(_snapshot: MatchLoadingSnapshot) -> void:
	pass


func _on_loading_aborted(_error_code: String, _user_message: String, _snapshot: MatchLoadingSnapshot) -> void:
	pass


func _on_loading_committed(_config: BattleStartConfig, _snapshot: MatchLoadingSnapshot) -> void:
	if _resume_coordinator != null:
		_resume_coordinator.on_match_committed(_config)
	_log("loading_committed", {"battle_id": battle_id, "assignment_id": assignment_id})


func _log(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("%s[server_battle_runtime] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "net.online.server_battle_runtime")
