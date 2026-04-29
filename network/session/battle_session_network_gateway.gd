class_name BattleSessionNetworkGateway
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleSessionBootstrapScript = preload("res://network/session/battle_session_bootstrap.gd")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const NativeAuthorityBatchBridgeScript = preload("res://gameplay/native_bridge/native_authority_batch_bridge.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const DEDICATED_CLIENT_CONNECT_RETRY_DELAYS_SEC: Array[float] = [0.5, 1.0, 2.0, 4.0]

var _adapter = null
var _dedicated_match_started: bool = false
var _dedicated_first_full_authority_received: bool = false
var _logged_waiting_for_match_start: bool = false
var _logged_waiting_for_authority_opening: bool = false
var _logged_opening_input_freeze: bool = false
var _dedicated_opening_ack_sent: bool = false
var _dedicated_client_connect_retry_delays_sec: Array[float] = DEDICATED_CLIENT_CONNECT_RETRY_DELAYS_SEC.duplicate()
var _dedicated_client_connect_retry_attempt: int = 0
var _dedicated_client_connect_retry_deadline_msec: int = 0
var _dedicated_client_connect_retry_host: String = ""
var _dedicated_client_connect_retry_port: int = 0
var _dedicated_client_connect_retry_timeout_sec: float = 5.0
var _authority_batch_bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()


func configure(adapter) -> void:
	_adapter = adapter


func ingest_dedicated_server_message(message) -> void:
	if _adapter == null or _adapter._bootstrap_client_runtime == null or message.is_empty():
		return
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if _is_waiting_for_dedicated_full_authority():
		if message_type == TransportMessageTypesScript.CHECKPOINT or message_type == TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
			_dedicated_first_full_authority_received = true
			_logged_waiting_for_authority_opening = false
			_send_opening_snapshot_ack(int(message.get("tick", 0)))
		else:
			return
	_adapter._bootstrap_client_runtime.ingest_network_message(message)
	_emit_client_runtime_tick()
	if message_type == TransportMessageTypesScript.MATCH_FINISHED and _adapter.current_context != null:
		_adapter._finished_emitted = true
		_adapter._lifecycle_state = _adapter.BattleLifecycleState.FINISHING


func start_client_runtime(config, options: Dictionary = {}) -> bool:
	_adapter.network_log_event.emit("client_runtime_start_request has_config=%s battle_id=%s match_id=%s authority=%s:%d topology=%s session_mode=%s transport_exists=%s transport_connected=%s" % [
		str(config != null),
		String(config.battle_id) if config != null else "",
		String(config.match_id) if config != null else "",
		String(config.authority_host) if config != null else "",
		int(config.authority_port) if config != null else 0,
		String(config.topology) if config != null else "",
		String(config.session_mode) if config != null else "",
		str(_adapter.transport != null),
		str(_adapter.transport != null and _adapter.transport.is_transport_connected()),
	])
	var preserved_transport = null
	if _adapter.transport != null and _adapter.transport.is_transport_connected() and _adapter.network_mode == _adapter.BattleNetworkMode.CLIENT:
		preserved_transport = _adapter.transport
		_adapter.transport = null
		_adapter.network_log_event.emit("client_runtime_preserve_connected_transport")
	var has_active_runtime: bool = _adapter.current_context != null \
		or _adapter.client_session != null \
		or _adapter.server_session != null \
		or _adapter.prediction_controller != null \
		or (_adapter._bootstrap_client_runtime != null and _adapter._bootstrap_client_runtime.is_active()) \
		or (_adapter._bootstrap_authority_runtime != null and _adapter._bootstrap_authority_runtime.is_match_running())
	if has_active_runtime:
		_adapter.shutdown_battle()
	if preserved_transport != null:
		_adapter.transport = preserved_transport
	_adapter._ensure_bootstrap_client_runtime()
	_adapter.start_config = config.duplicate_deep() if config != null else null
	if _adapter.start_config == null:
		_adapter.network_log_event.emit("client_runtime_start_rejected reason=missing_config")
		return false
	_adapter.network_mode = _adapter.BattleNetworkMode.CLIENT
	_dedicated_match_started = false
	_dedicated_first_full_authority_received = false
	_logged_waiting_for_match_start = false
	_logged_waiting_for_authority_opening = false
	_logged_opening_input_freeze = false
	_dedicated_opening_ack_sent = false
	_adapter._bootstrap_local_peer_id = int(options.get("local_peer_id", int(_adapter.start_config.local_peer_id if _adapter.start_config != null else _adapter._bootstrap_local_peer_id)))
	var controlled_peer_id := int(options.get("controlled_peer_id", int(_adapter.start_config.controlled_peer_id if _adapter.start_config != null else _adapter._bootstrap_local_peer_id)))
	_adapter._bootstrap_client_runtime.configure(_adapter._bootstrap_local_peer_id)
	_adapter._bootstrap_client_runtime.configure_controlled_peer(controlled_peer_id)
	var client_started: bool = _adapter._bootstrap_client_runtime.start_match(_adapter.start_config)
	_adapter.client_session = _adapter._bootstrap_client_runtime.client_session
	_adapter.prediction_controller = _adapter._bootstrap_client_runtime.prediction_controller
	_adapter.network_log_event.emit("client_runtime_bootstrap_result started=%s local_peer=%d controlled_peer=%d has_client_session=%s has_prediction=%s predicted_world=%s" % [
		str(client_started),
		_adapter._bootstrap_local_peer_id,
		controlled_peer_id,
		str(_adapter.client_session != null),
		str(_adapter.prediction_controller != null),
		str(_adapter.prediction_controller != null and _adapter.prediction_controller.predicted_sim_world != null),
	])
	if not client_started or _adapter.client_session == null or _adapter.prediction_controller == null:
		return false
	_adapter._local_peer_id = _adapter._bootstrap_local_peer_id
	_adapter._finished_emitted = false
	_adapter._correction_count = 0
	_adapter._last_correction_summary = ""
	_adapter._last_resync_tick = -1
	if not _adapter.prediction_controller.prediction_corrected.is_connected(_adapter._on_prediction_corrected):
		_adapter.prediction_controller.prediction_corrected.connect(_adapter._on_prediction_corrected)
	if not _adapter.prediction_controller.full_visual_resync.is_connected(_adapter._on_full_visual_resync):
		_adapter.prediction_controller.full_visual_resync.connect(_adapter._on_full_visual_resync)
	_adapter.visual_sync_controller = VisualSyncController.new()
	_adapter.add_child(_adapter.visual_sync_controller)
	_adapter.current_context = BattleContext.new()
	_adapter.current_context.battle_start_config = _adapter.start_config.duplicate_deep()
	_adapter.current_context.sim_world = _adapter.prediction_controller.predicted_sim_world
	_adapter.current_context.tick_runner = _adapter.prediction_controller.predicted_sim_world.tick_runner if _adapter.prediction_controller.predicted_sim_world != null else null
	_adapter.current_context.client_session = _adapter.client_session
	_adapter.current_context.prediction_controller = _adapter.prediction_controller
	_adapter.current_context.rollback_controller = _adapter.prediction_controller.rollback_controller
	_adapter.current_context.visual_sync_controller = _adapter.visual_sync_controller
	_adapter.adapter_configured.emit()
	if _adapter.transport == null and not String(_adapter.start_config.authority_host).is_empty() and int(_adapter.start_config.authority_port) > 0:
		_adapter.network_host = String(_adapter.start_config.authority_host)
		_adapter.network_port = int(_adapter.start_config.authority_port)
		_adapter.network_log_event.emit("client_runtime_initialize_transport target=%s:%d match_id=%s battle_id=%s" % [
			_adapter.network_host,
			_adapter.network_port,
			String(_adapter.start_config.match_id),
			String(_adapter.start_config.battle_id),
		])
		initialize_transport({})
	elif _adapter.transport == null:
		_adapter.network_log_event.emit("client_runtime_no_transport reason=missing_authority target=%s:%d" % [
			String(_adapter.start_config.authority_host),
			int(_adapter.start_config.authority_port),
		])
	else:
		_adapter.network_log_event.emit("client_runtime_reusing_transport connected=%s local_peer=%d peers=%s" % [
			str(_adapter.transport.is_transport_connected()),
			_adapter.transport.get_local_peer_id() if _adapter.transport.has_method("get_local_peer_id") else 0,
			str(_adapter.transport.get_remote_peer_ids() if _adapter.transport.has_method("get_remote_peer_ids") else []),
		])
	if _adapter.transport != null and _adapter.transport.is_transport_connected() \
			and String(_adapter.start_config.session_mode) == "network_client" \
			and String(_adapter.start_config.topology) == "dedicated_server" \
			and not String(_adapter.start_config.match_id).is_empty() \
			and int(_adapter.start_config.server_match_revision) > 0:
		_adapter.transport.send_to_peer(1, {
			"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
			"match_id": String(_adapter.start_config.match_id),
			"revision": int(_adapter.start_config.server_match_revision),
			"sender_peer_id": _adapter._bootstrap_local_peer_id,
		})
		_adapter.network_log_event.emit("client_runtime_match_loading_ready_sent match_id=%s revision=%d sender_peer=%d" % [
			String(_adapter.start_config.match_id),
			int(_adapter.start_config.server_match_revision),
			_adapter._bootstrap_local_peer_id,
		])
	_inject_pending_resume_snapshot()
	_adapter.network_log_event.emit("client_runtime_start_ok battle_id=%s match_id=%s transport_connected=%s waiting_dedicated_opening=%s" % [
		String(_adapter.start_config.battle_id),
		String(_adapter.start_config.match_id),
		str(_adapter.transport != null and _adapter.transport.is_transport_connected()),
		str(_is_waiting_for_dedicated_opening()),
	])
	return true


func advance_client_runtime_tick(local_input: Dictionary = {}) -> void:
	if _adapter._bootstrap_client_runtime == null:
		_adapter.network_log_event.emit("client_tick_skip reason=no_client_runtime mode=%d transport=%s" % [_adapter.network_mode, str(_adapter.transport != null)])
		return
	if _is_waiting_for_dedicated_opening():
		_log_dedicated_input_deferred()
		_poll_client_transport()
		return
	if _is_opening_input_frozen():
		_log_opening_input_freeze_deferred()
		_poll_client_transport()
		_emit_client_runtime_tick()
		return
	var input_message: Dictionary = _adapter._bootstrap_client_runtime.build_local_input_message(local_input)
	if not input_message.is_empty() and _adapter.transport != null and _adapter.transport.is_transport_connected():
		_adapter.transport.send_to_peer(1, input_message)
	_poll_client_transport()
	_emit_client_runtime_tick()


func poll_dedicated_client_transport() -> void:
	if _adapter == null or _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	if not _is_waiting_for_dedicated_opening():
		return
	_log_dedicated_input_deferred()
	_poll_client_transport()


func is_dedicated_authority_ready() -> bool:
	return _dedicated_first_full_authority_received


func _poll_client_transport() -> void:
	_restart_dedicated_client_transport_if_due()
	if _adapter.transport != null:
		_adapter.transport.poll()
		var incoming: Array = _adapter.transport.consume_incoming()
		var connected: bool = _adapter.transport.is_transport_connected()
		var local_peer: int = _adapter.transport.get_local_peer_id() if _adapter.transport.has_method("get_local_peer_id") else -1
		var remote_peers: Array = _adapter.transport.get_remote_peer_ids() if _adapter.transport.has_method("get_remote_peer_ids") else []
		if incoming.is_empty():
			_adapter.network_log_event.emit("client_tick_poll incoming=0 connected=%s local_peer=%d remote_peers=%s predicted_tick=%d ack_tick=%d" % [
				str(connected),
				local_peer,
				str(remote_peers),
				_adapter.prediction_controller.predicted_until_tick if _adapter.prediction_controller != null else -1,
				_adapter.client_session.last_confirmed_tick if _adapter.client_session != null else -1,
			])
		else:
			_adapter.network_log_event.emit("client_tick_poll incoming=%d types=%s connected=%s local_peer=%d remote_peers=%s predicted_tick=%d ack_tick=%d" % [
				incoming.size(),
				str(_describe_message_types(incoming)),
				str(connected),
				local_peer,
				str(remote_peers),
				_adapter.prediction_controller.predicted_until_tick if _adapter.prediction_controller != null else -1,
				_adapter.client_session.last_confirmed_tick if _adapter.client_session != null else -1,
			])
		if not incoming.is_empty():
			_route_client_poll_batch(incoming)


func inject_pending_resume_snapshot() -> void:
	_inject_pending_resume_snapshot()


func initialize_transport(debug_profile: Dictionary = {}, preserve_retry_state: bool = false) -> void:
	if _adapter == null:
		return
	shutdown_transport()
	_adapter.transport = BattleSessionBootstrapScript.create_transport(_adapter.network_mode)
	if _adapter.transport == null:
		return
	_adapter.add_child(_adapter.transport)
	_connect_transport_bridge_signals()
	var transport_config := BattleSessionBootstrapScript.build_transport_config(
		_adapter.network_mode,
		_adapter.start_config,
		_adapter._local_peer_id,
		_adapter.network_host,
		_adapter.network_port,
		_adapter.network_max_clients,
		debug_profile
	)
	if _adapter.network_mode == _adapter.BattleNetworkMode.CLIENT:
		transport_config["connect_timeout_seconds"] = float(debug_profile.get("connect_timeout_seconds", 5.0))
	_adapter.transport.initialize(transport_config)
	if not preserve_retry_state and _is_dedicated_client_transport_target():
		_begin_dedicated_client_connect_retry_tracking(
			String(transport_config.get("host", _adapter.network_host)),
			int(transport_config.get("port", _adapter.network_port)),
			float(transport_config.get("connect_timeout_seconds", 5.0))
		)


func shutdown_transport() -> void:
	if _adapter == null or _adapter.transport == null or not is_instance_valid(_adapter.transport):
		if _adapter != null:
			_adapter.transport = null
		return
	_adapter.transport.shutdown()
	if _adapter.transport.get_parent() == _adapter:
		_adapter.remove_child(_adapter.transport)
	_adapter.transport.free()
	_adapter.transport = null


func configure_host(local_peer_id: int = 1) -> void:
	_adapter._ensure_bootstrap_authority_runtime()
	_adapter.network_mode = _adapter.BattleNetworkMode.HOST
	_adapter._bootstrap_local_peer_id = local_peer_id
	_adapter._bootstrap_authority_runtime.configure(local_peer_id)


func configure_client(local_peer_id: int = 0) -> void:
	_adapter._ensure_bootstrap_client_runtime()
	_adapter.network_mode = _adapter.BattleNetworkMode.CLIENT
	_adapter._bootstrap_local_peer_id = local_peer_id


func set_local_peer_id(local_peer_id: int) -> void:
	_adapter._bootstrap_local_peer_id = local_peer_id


func notify_dedicated_server_transport_connected() -> void:
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	_adapter.network_transport_connected.emit()


func notify_dedicated_server_transport_disconnected() -> void:
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	_adapter.network_transport_disconnected.emit()
	_adapter.network_transport_error.emit(ERR_CONNECTION_ERROR, "Dedicated server transport disconnected")


func notify_dedicated_server_transport_error(error_code: String, user_message: String) -> void:
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	_adapter.network_transport_error.emit(ERR_CONNECTION_ERROR, "%s: %s" % [error_code, user_message])


func start_host_match(config) -> bool:
	return _adapter._start_runtime_session(_adapter.BattleNetworkMode.HOST, config, {
		"local_peer_id": _adapter._bootstrap_local_peer_id,
	})


func build_start_config(snapshot):
	_adapter._ensure_bootstrap_coordinator()
	return _adapter._bootstrap_coordinator.build_start_config(snapshot)


func route_messages(messages: Array) -> void:
	_adapter._ensure_runtime_message_router()
	_adapter._runtime_message_router.route_messages(messages)


func _route_client_poll_batch(incoming: Array) -> void:
	var authority_messages: Array = []
	var non_authority_messages: Array = []
	for raw_message in incoming:
		if not (raw_message is Dictionary):
			continue
		var message: Dictionary = raw_message
		if _is_client_authority_sync_message(message):
			authority_messages.append(message)
		else:
			non_authority_messages.append(message)
	_route_non_authority_messages(non_authority_messages)
	_ingest_client_authority_messages(authority_messages)


func _ingest_client_authority_messages(authority_messages: Array) -> void:
	if authority_messages.is_empty() or _adapter == null or _adapter._bootstrap_client_runtime == null:
		return
	var cursor: Dictionary = _adapter._bootstrap_client_runtime.build_authority_cursor()
	cursor["waiting_full_authority"] = _is_waiting_for_dedicated_full_authority()
	var batch: Dictionary = _authority_batch_bridge.coalesce_client_authority_batch(authority_messages, cursor)
	var latest_snapshot: Dictionary = batch.get("latest_snapshot_message", {})
	var emit_opening_tick := false
	if _is_waiting_for_dedicated_full_authority():
		if latest_snapshot.is_empty():
			if not _logged_waiting_for_authority_opening:
				_logged_waiting_for_authority_opening = true
				_adapter.network_log_event.emit("client_runtime_ingest_deferred type=authority_batch reason=waiting_full_authority match_id=%s" % [
					String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
				])
			return
		_dedicated_first_full_authority_received = true
		_logged_waiting_for_authority_opening = false
		emit_opening_tick = true
		_send_opening_snapshot_ack(int(latest_snapshot.get("tick", 0)))
		_adapter.network_log_event.emit("client_authoritative_opening_ready type=%s tick=%d local_peer=%d controlled_peer=%d" % [
			String(latest_snapshot.get("message_type", latest_snapshot.get("msg_type", ""))),
			int(latest_snapshot.get("tick", 0)),
			_adapter._bootstrap_local_peer_id,
			_adapter._bootstrap_client_runtime.controlled_peer_id if _adapter._bootstrap_client_runtime != null else -1,
	])
	_adapter._bootstrap_client_runtime.ingest_authority_batch(batch)
	var terminal_messages: Variant = batch.get("terminal_messages", [])
	if terminal_messages is Array and not terminal_messages.is_empty() and _adapter.current_context != null:
		_adapter._finished_emitted = true
		_adapter._lifecycle_state = _adapter.BattleLifecycleState.FINISHING
	if emit_opening_tick:
		_emit_client_runtime_tick()


func _is_client_authority_sync_message(message: Dictionary) -> bool:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	return message_type == TransportMessageTypesScript.INPUT_ACK \
		or message_type == TransportMessageTypesScript.STATE_SUMMARY \
		or message_type == TransportMessageTypesScript.STATE_DELTA \
		or message_type == TransportMessageTypesScript.CHECKPOINT \
		or message_type == TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT \
		or message_type == TransportMessageTypesScript.MATCH_FINISHED


func _route_non_authority_messages(messages: Array) -> void:
	if messages.is_empty():
		return
	route_messages(messages)


func build_host_tick_messages(local_input: Dictionary = {}) -> Array:
	if _adapter._bootstrap_authority_runtime == null:
		return []
	return _adapter._bootstrap_authority_runtime.advance_authoritative_tick(local_input)


func build_client_input_message(local_input: Dictionary = {}) -> Dictionary:
	if _adapter._bootstrap_client_runtime == null:
		return {}
	return _adapter._bootstrap_client_runtime.build_local_input_message(local_input)


func is_host_match_running() -> bool:
	return _adapter._bootstrap_authority_runtime != null and _adapter._bootstrap_authority_runtime.is_match_running()


func is_client_active() -> bool:
	return _adapter._bootstrap_client_runtime != null and _adapter._bootstrap_client_runtime.is_active()


func build_client_metrics() -> Dictionary:
	if _adapter._bootstrap_client_runtime == null:
		return {}
	return _adapter._bootstrap_client_runtime.build_metrics()


func shutdown_bootstrap() -> void:
	if _adapter._battle_session_bootstrap != null:
		_adapter._battle_session_bootstrap.shutdown()
		if is_instance_valid(_adapter._battle_session_bootstrap):
			_adapter._battle_session_bootstrap.queue_free()
	_adapter._battle_session_bootstrap = null
	_adapter._bootstrap_authority_runtime = null
	_adapter._bootstrap_client_runtime = null
	_adapter._bootstrap_coordinator = null
	_adapter._runtime_message_router = null
	shutdown_transport()
	_adapter.start_config = null
	_adapter._bootstrap_local_peer_id = 0


func start_host_transport(port: int, max_clients: int) -> void:
	_adapter._ensure_bootstrap_authority_runtime()
	_adapter.network_port = port
	_adapter.network_max_clients = max_clients
	_adapter.network_mode = _adapter.BattleNetworkMode.HOST
	initialize_transport({})


func start_client_transport(host: String, port: int, connect_timeout_seconds: float = 5.0) -> void:
	_adapter._ensure_bootstrap_client_runtime()
	_adapter.network_host = host
	_adapter.network_port = port
	_adapter.network_mode = _adapter.BattleNetworkMode.CLIENT
	initialize_transport({
		"connect_timeout_seconds": connect_timeout_seconds,
	})


func poll_transport() -> void:
	if _adapter.transport == null:
		return
	_adapter.transport.poll()
	route_messages(_adapter.transport.consume_incoming())


func transport_connected() -> bool:
	return _adapter.transport != null and _adapter.transport.is_transport_connected()


func transport_remote_peer_ids() -> Array:
	if _adapter.transport == null:
		return []
	return _adapter.transport.get_remote_peer_ids()


func transport_local_peer_id() -> int:
	if _adapter.transport == null:
		return 0
	return _adapter.transport.get_local_peer_id()


func send_to_peer(peer_id: int, message: Dictionary) -> void:
	if _adapter.transport == null:
		return
	_adapter.transport.send_to_peer(peer_id, message)


func broadcast(message: Dictionary) -> void:
	if _adapter.transport == null:
		return
	_adapter.transport.broadcast(message)


func on_bootstrap_join_battle_request(message) -> void:
	if _adapter.network_mode != _adapter.BattleNetworkMode.HOST:
		return
	_adapter.network_log_event.emit("Host received join request from peer %d" % int(message.get("sender_peer_id", -1)))


func on_bootstrap_join_battle_accepted(message) -> void:
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return
	_adapter._ensure_bootstrap_coordinator()
	var config := BattleStartConfig.from_dict(message.get("start_config", {}))
	var validation: Dictionary = _adapter._bootstrap_coordinator.validate_start_config(config)
	if not bool(validation.get("ok", false)):
		_adapter.network_log_event.emit("Client rejected config: %s" % str(validation.get("errors", [])))
		return
	var resolved_peer_id: int = int(config.local_peer_id) if int(config.local_peer_id) > 0 else _adapter._bootstrap_local_peer_id
	var started: bool = _adapter._start_runtime_session(_adapter.BattleNetworkMode.CLIENT, config, {
		"local_peer_id": resolved_peer_id,
		"controlled_peer_id": int(config.controlled_peer_id) if int(config.controlled_peer_id) > 0 else resolved_peer_id,
	})
	if started and _adapter.current_context != null:
		_adapter.network_log_event.emit("client_runtime_rebound local_peer=%d controlled_peer=%d match_id=%s" % [
			_adapter._bootstrap_local_peer_id,
			_adapter._bootstrap_client_runtime.controlled_peer_id if _adapter._bootstrap_client_runtime != null else -1,
			String(config.match_id),
		])
		_adapter.battle_context_created.emit(_adapter.current_context)


func on_bootstrap_join_battle_rejected(message) -> void:
	_adapter.network_log_event.emit("Join rejected: %s" % str(message))
	var error_code := String(message.get("error", "MATCH_START_REJECTED"))
	var user_message := String(message.get("user_message", "Match start rejected"))
	_adapter.network_transport_error.emit(ERR_CONNECTION_ERROR, "%s: %s" % [error_code, user_message])
	shutdown_bootstrap()


func on_bootstrap_input_frame_message(message) -> void:
	if (_adapter.network_mode == _adapter.BattleNetworkMode.HOST or _adapter.network_mode == _adapter.BattleNetworkMode.LOCAL_LOOPBACK) and _adapter._bootstrap_authority_runtime != null:
		_adapter._bootstrap_authority_runtime.ingest_network_message(message)


func on_bootstrap_client_runtime_message(message) -> void:
	if (_adapter.network_mode == _adapter.BattleNetworkMode.CLIENT or _adapter.network_mode == _adapter.BattleNetworkMode.LOCAL_LOOPBACK) and _adapter._bootstrap_client_runtime != null:
		var message_type := String(message.get("message_type", message.get("msg_type", "")))
		var emit_opening_tick := false
		if _is_waiting_for_dedicated_full_authority():
			if message_type == TransportMessageTypesScript.CHECKPOINT or message_type == TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
				_dedicated_first_full_authority_received = true
				_logged_waiting_for_authority_opening = false
				emit_opening_tick = true
				_send_opening_snapshot_ack(int(message.get("tick", 0)))
				_adapter.network_log_event.emit("client_authoritative_opening_ready type=%s tick=%d local_peer=%d controlled_peer=%d" % [
					message_type,
					int(message.get("tick", 0)),
					_adapter._bootstrap_local_peer_id,
					_adapter._bootstrap_client_runtime.controlled_peer_id if _adapter._bootstrap_client_runtime != null else -1,
				])
			else:
				if not _logged_waiting_for_authority_opening:
					_logged_waiting_for_authority_opening = true
					_adapter.network_log_event.emit("client_runtime_ingest_deferred type=%s reason=waiting_full_authority match_id=%s" % [
						message_type,
						String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
					])
				return
		_adapter.network_log_event.emit("client_runtime_ingest type=%s tick=%d local_peer=%d controlled_peer=%d" % [
			message_type,
			int(message.get("tick", message.get("ack_tick", 0))),
			_adapter._bootstrap_local_peer_id,
			_adapter._bootstrap_client_runtime.controlled_peer_id if _adapter._bootstrap_client_runtime != null else -1,
		])
		_adapter._bootstrap_client_runtime.ingest_network_message(message)
		if emit_opening_tick:
			_emit_client_runtime_tick()


func on_bootstrap_match_start_message(message) -> void:
	_dedicated_match_started = true
	_logged_waiting_for_match_start = false
	_adapter.network_log_event.emit("client_match_start_received match_id=%s local_peer=%d controlled_peer=%d" % [
		String(message.get("match_id", "")),
		_adapter._bootstrap_local_peer_id,
		_adapter._bootstrap_client_runtime.controlled_peer_id if _adapter._bootstrap_client_runtime != null else -1,
	])


func on_bootstrap_match_finished_message(message) -> void:
	if (_adapter.network_mode == _adapter.BattleNetworkMode.CLIENT or _adapter.network_mode == _adapter.BattleNetworkMode.LOCAL_LOOPBACK) and _adapter._bootstrap_client_runtime != null:
		_adapter._bootstrap_client_runtime.ingest_network_message(message)


func on_bootstrap_unhandled_message(message) -> void:
	if not message.is_empty():
		_adapter.network_log_event.emit("Unhandled message %s" % str(message.get("message_type", message.get("msg_type", "unknown"))))


func _connect_transport_bridge_signals() -> void:
	if _adapter.transport == null:
		return
	if not _adapter.transport.connected.is_connected(_on_transport_connected):
		_adapter.transport.connected.connect(_on_transport_connected)
	if not _adapter.transport.disconnected.is_connected(_on_transport_disconnected):
		_adapter.transport.disconnected.connect(_on_transport_disconnected)
	if not _adapter.transport.peer_connected.is_connected(_on_transport_peer_connected):
		_adapter.transport.peer_connected.connect(_on_transport_peer_connected)
	if not _adapter.transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
		_adapter.transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	if not _adapter.transport.transport_error.is_connected(_on_transport_error):
		_adapter.transport.transport_error.connect(_on_transport_error)


func _inject_pending_resume_snapshot() -> void:
	if _adapter.pending_resume_snapshot == null or _adapter._bootstrap_client_runtime == null:
		return
	if _adapter.pending_resume_snapshot.checkpoint_message.is_empty():
		_adapter.pending_resume_snapshot = null
		return
	_adapter._bootstrap_client_runtime.inject_resume_checkpoint_message(_adapter.pending_resume_snapshot.checkpoint_message)
	_adapter.pending_resume_snapshot = null


func _describe_message_types(messages: Array) -> Array:
	var result: Array = []
	for message in messages:
		if not (message is Dictionary):
			result.append("<invalid>")
			continue
		result.append(String((message as Dictionary).get("message_type", (message as Dictionary).get("msg_type", ""))))
	return result


func _emit_client_runtime_tick() -> void:
	if _adapter.current_context == null or _adapter.prediction_controller == null or _adapter.current_context.sim_world == null:
		return
	_adapter.current_context.sim_world = _adapter.prediction_controller.predicted_sim_world
	_adapter.current_context.tick_runner = _adapter.prediction_controller.predicted_sim_world.tick_runner if _adapter.prediction_controller.predicted_sim_world != null else null
	var world = _adapter.current_context.sim_world
	var authoritative_events: Array = _adapter._bootstrap_client_runtime.consume_pending_authoritative_events() if _adapter._bootstrap_client_runtime != null and _adapter._bootstrap_client_runtime.has_method("consume_pending_authoritative_events") else []
	_log_gateway_explosion_events(world.state.match_state.tick if world != null else 0, authoritative_events)
	var tick_result := {
		"tick": world.state.match_state.tick if world != null else 0,
		"events": authoritative_events,
		"phase": world.state.match_state.phase if world != null else MatchState.Phase.PLAYING,
	}
	_adapter.authoritative_tick_completed.emit(_adapter.current_context, tick_result, _adapter._build_runtime_metrics())


func _log_gateway_explosion_events(tick_id: int, events: Array) -> void:
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_EXPLODED:
			continue
		var covered_cells: Array = event.payload.get("covered_cells", [])
		_adapter.network_log_event.emit(
			"QQT_EXPLOSION_TRACE stage=gateway_emit tick=%d event_tick=%d bubble_id=%d owner=%d cell=(%d,%d) covered_cells=%d payload_keys=%s" % [
				tick_id,
				int(event.tick),
				int(event.payload.get("bubble_id", event.payload.get("entity_id", -1))),
				int(event.payload.get("owner_player_id", -1)),
				int(event.payload.get("cell_x", -1)),
				int(event.payload.get("cell_y", -1)),
				covered_cells.size(),
				str(event.payload.keys()),
			]
		)


func _send_opening_snapshot_ack(snapshot_tick: int) -> void:
	if _dedicated_opening_ack_sent:
		return
	if _adapter == null or _adapter.transport == null or not _adapter.transport.is_transport_connected():
		return
	if _adapter.start_config == null:
		return
	_dedicated_opening_ack_sent = true
	_adapter.transport.send_to_peer(1, {
		"message_type": TransportMessageTypesScript.OPENING_SNAPSHOT_ACK,
		"msg_type": TransportMessageTypesScript.OPENING_SNAPSHOT_ACK,
		"match_id": String(_adapter.start_config.match_id),
		"sender_peer_id": _adapter._bootstrap_local_peer_id,
		"peer_id": _adapter._bootstrap_local_peer_id,
		"tick": snapshot_tick,
	})


func _is_waiting_for_dedicated_match_start() -> bool:
	if _adapter == null or _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return false
	if _adapter.start_config == null:
		return false
	return String(_adapter.start_config.topology) == "dedicated_server" \
		and String(_adapter.start_config.session_mode) == "network_client" \
		and not _dedicated_match_started


func _is_waiting_for_dedicated_full_authority() -> bool:
	if _adapter == null or _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return false
	if _adapter.start_config == null:
		return false
	return String(_adapter.start_config.topology) == "dedicated_server" \
		and String(_adapter.start_config.session_mode) == "network_client" \
		and _dedicated_match_started \
		and not _dedicated_first_full_authority_received


func _is_waiting_for_dedicated_opening() -> bool:
	return _is_waiting_for_dedicated_match_start() or _is_waiting_for_dedicated_full_authority()


func _is_opening_input_frozen() -> bool:
	if _adapter == null or _adapter.start_config == null:
		return false
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return false
	if String(_adapter.start_config.topology) != "dedicated_server":
		return false
	if String(_adapter.start_config.session_mode) != "network_client":
		return false
	var freeze_ticks := int(_adapter.start_config.opening_input_freeze_ticks)
	if freeze_ticks <= 0:
		return false
	var authority_tick: int = int(_adapter.prediction_controller.authoritative_tick) if _adapter.prediction_controller != null else int(_adapter.start_config.start_tick)
	return int(authority_tick) < int(_adapter.start_config.start_tick) + freeze_ticks


func _log_dedicated_input_deferred() -> void:
	if _is_waiting_for_dedicated_match_start():
		if not _logged_waiting_for_match_start:
			_logged_waiting_for_match_start = true
			_adapter.network_log_event.emit("client_input_deferred reason=waiting_match_start match_id=%s" % [
				String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
			])
		return
	if _is_waiting_for_dedicated_full_authority() and not _logged_waiting_for_authority_opening:
		_logged_waiting_for_authority_opening = true
		_adapter.network_log_event.emit("client_input_deferred reason=waiting_full_authority match_id=%s" % [
			String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
		])


func _log_opening_input_freeze_deferred() -> void:
	if _logged_opening_input_freeze:
		return
	_logged_opening_input_freeze = true
	var end_tick := int(_adapter.start_config.start_tick) + int(_adapter.start_config.opening_input_freeze_ticks) if _adapter.start_config != null else 0
	_adapter.network_log_event.emit("client_input_deferred reason=opening_input_freeze until_tick=%d match_id=%s" % [
		end_tick,
		String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
	])


func _on_transport_connected() -> void:
	_reset_dedicated_client_connect_retry_tracking()
	_adapter.network_log_event.emit("gateway_transport_connected local_peer=%d remote_peers=%s match_id=%s" % [
		_adapter.transport.get_local_peer_id() if _adapter.transport != null and _adapter.transport.has_method("get_local_peer_id") else 0,
		str(_adapter.transport.get_remote_peer_ids() if _adapter.transport != null and _adapter.transport.has_method("get_remote_peer_ids") else []),
		String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
	])
	_adapter.network_transport_connected.emit()
	if _adapter.network_mode == _adapter.BattleNetworkMode.CLIENT and _adapter.transport != null and _adapter.start_config != null:
		var transport_peer_id: int = _adapter.transport.get_local_peer_id() if _adapter.transport.has_method("get_local_peer_id") else 0
		if transport_peer_id > 0 and _adapter._bootstrap_local_peer_id <= 0:
			_adapter._bootstrap_local_peer_id = transport_peer_id
		var battle_id := String(_adapter.start_config.battle_id)
		if battle_id.is_empty():
			_adapter.network_log_event.emit("battle_entry_request_skip reason=missing_battle_id match_id=%s local_peer=%d transport_peer=%d" % [
				String(_adapter.start_config.match_id),
				_adapter._bootstrap_local_peer_id,
				transport_peer_id,
			])
			return
		var request_payload := {
			"message_type": TransportMessageTypesScript.BATTLE_ENTRY_REQUEST,
			"battle_id": battle_id,
			"sender_peer_id": _adapter._bootstrap_local_peer_id if _adapter._bootstrap_local_peer_id > 0 else transport_peer_id,
		}
		var has_entry_context := false
		var has_ticket := false
		var app_runtime = AppRuntimeRootScript.get_existing(_adapter.get_tree())
		if app_runtime != null and "current_battle_entry_context" in app_runtime and app_runtime.current_battle_entry_context != null:
			has_entry_context = true
			var entry_context = app_runtime.current_battle_entry_context
			request_payload["battle_ticket"] = String(entry_context.battle_ticket)
			request_payload["battle_ticket_id"] = String(entry_context.battle_ticket_id)
			request_payload["assignment_id"] = String(entry_context.assignment_id)
			request_payload["match_id"] = String(entry_context.match_id)
			has_ticket = not String(entry_context.battle_ticket).is_empty() and not String(entry_context.battle_ticket_id).is_empty()
		if app_runtime != null and "auth_session_state" in app_runtime and app_runtime.auth_session_state != null:
			request_payload["device_session_id"] = String(app_runtime.auth_session_state.device_session_id)
		_adapter.network_log_event.emit("battle_entry_request_send battle_id=%s sender_peer_id=%d has_entry_context=%s has_ticket=%s" % [
			battle_id,
			int(request_payload.get("sender_peer_id", 0)),
			str(has_entry_context),
			str(has_ticket),
		])
		_adapter.transport.send_to_peer(1, request_payload)
		_adapter.network_log_event.emit("battle_entry_request_sent type=%s battle_id=%s match_id=%s assignment_id=%s ticket_id=%s" % [
			String(request_payload.get("message_type", "")),
			battle_id,
			String(request_payload.get("match_id", "")),
			String(request_payload.get("assignment_id", "")),
			String(request_payload.get("battle_ticket_id", "")),
		])


func _on_transport_disconnected() -> void:
	_adapter.network_log_event.emit("gateway_transport_disconnected match_id=%s waiting_opening=%s retry_attempt=%d" % [
		String(_adapter.start_config.match_id) if _adapter.start_config != null else "",
		str(_is_waiting_for_dedicated_opening()),
		_dedicated_client_connect_retry_attempt,
	])
	_adapter.network_transport_disconnected.emit()


func _on_transport_peer_connected(peer_id: int) -> void:
	_adapter.network_log_event.emit("gateway_transport_peer_connected peer=%d local=%d peers=%s" % [
		peer_id,
		_adapter.transport.get_local_peer_id() if _adapter.transport != null and _adapter.transport.has_method("get_local_peer_id") else 0,
		str(_adapter.transport.get_remote_peer_ids() if _adapter.transport != null and _adapter.transport.has_method("get_remote_peer_ids") else []),
	])
	_adapter.network_transport_peer_connected.emit(peer_id)


func _on_transport_peer_disconnected(peer_id: int) -> void:
	_adapter.network_log_event.emit("gateway_transport_peer_disconnected peer=%d local=%d peers=%s" % [
		peer_id,
		_adapter.transport.get_local_peer_id() if _adapter.transport != null and _adapter.transport.has_method("get_local_peer_id") else 0,
		str(_adapter.transport.get_remote_peer_ids() if _adapter.transport != null and _adapter.transport.has_method("get_remote_peer_ids") else []),
	])
	_adapter.network_transport_peer_disconnected.emit(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	_adapter.network_log_event.emit("gateway_transport_error code=%d message=%s waiting_opening=%s retry_attempt=%d target=%s:%d" % [
		code,
		message,
		str(_is_waiting_for_dedicated_opening()),
		_dedicated_client_connect_retry_attempt,
		_dedicated_client_connect_retry_host,
		_dedicated_client_connect_retry_port,
	])
	if _schedule_dedicated_client_connect_retry(code, message):
		return
	_adapter.network_transport_error.emit(code, message)


func _begin_dedicated_client_connect_retry_tracking(host: String, port: int, connect_timeout_seconds: float) -> void:
	_dedicated_client_connect_retry_attempt = 0
	_dedicated_client_connect_retry_deadline_msec = 0
	_dedicated_client_connect_retry_host = host
	_dedicated_client_connect_retry_port = port
	_dedicated_client_connect_retry_timeout_sec = max(connect_timeout_seconds, 0.5)


func _reset_dedicated_client_connect_retry_tracking() -> void:
	_dedicated_client_connect_retry_attempt = 0
	_dedicated_client_connect_retry_deadline_msec = 0
	_dedicated_client_connect_retry_host = ""
	_dedicated_client_connect_retry_port = 0
	_dedicated_client_connect_retry_timeout_sec = 5.0


func _schedule_dedicated_client_connect_retry(code: int, message: String) -> bool:
	if not _should_retry_dedicated_client_connect_error(code):
		return false
	if _dedicated_client_connect_retry_port <= 0 or _dedicated_client_connect_retry_host.is_empty():
		return false
	if _dedicated_client_connect_retry_attempt >= _dedicated_client_connect_retry_delays_sec.size():
		_adapter.network_log_event.emit("battle_transport_retry_exhausted host=%s port=%d attempts=%d code=%d message=%s" % [
			_dedicated_client_connect_retry_host,
			_dedicated_client_connect_retry_port,
			_dedicated_client_connect_retry_attempt,
			code,
			message,
		])
		return false
	var delay_sec := float(_dedicated_client_connect_retry_delays_sec[_dedicated_client_connect_retry_attempt])
	_dedicated_client_connect_retry_attempt += 1
	_dedicated_client_connect_retry_deadline_msec = Time.get_ticks_msec() + int(max(delay_sec, 0.0) * 1000.0)
	_adapter.network_log_event.emit("battle_transport_retry_scheduled host=%s port=%d attempt=%d max_attempts=%d delay=%.2f code=%d message=%s" % [
		_dedicated_client_connect_retry_host,
		_dedicated_client_connect_retry_port,
		_dedicated_client_connect_retry_attempt,
		_dedicated_client_connect_retry_delays_sec.size(),
		delay_sec,
		code,
		message,
	])
	return true


func _restart_dedicated_client_transport_if_due() -> void:
	if _dedicated_client_connect_retry_deadline_msec <= 0:
		return
	if Time.get_ticks_msec() < _dedicated_client_connect_retry_deadline_msec:
		return
	_dedicated_client_connect_retry_deadline_msec = 0
	if not _is_waiting_for_dedicated_opening():
		return
	if _adapter.transport != null and _adapter.transport.is_transport_connected():
		_reset_dedicated_client_connect_retry_tracking()
		return
	_adapter.network_host = _dedicated_client_connect_retry_host
	_adapter.network_port = _dedicated_client_connect_retry_port
	_adapter.network_mode = _adapter.BattleNetworkMode.CLIENT
	_adapter.network_log_event.emit("battle_transport_retry_start host=%s port=%d attempt=%d timeout=%.2f" % [
		_dedicated_client_connect_retry_host,
		_dedicated_client_connect_retry_port,
		_dedicated_client_connect_retry_attempt,
		_dedicated_client_connect_retry_timeout_sec,
	])
	initialize_transport({
		"connect_timeout_seconds": _dedicated_client_connect_retry_timeout_sec,
	}, true)


func _should_retry_dedicated_client_connect_error(code: int) -> bool:
	if _adapter == null:
		return false
	if _adapter.network_mode != _adapter.BattleNetworkMode.CLIENT:
		return false
	if not _is_waiting_for_dedicated_opening():
		return false
	if _adapter.transport != null and _adapter.transport.is_transport_connected():
		return false
	return code == ERR_TIMEOUT or code == ERR_CANT_CONNECT


func _is_dedicated_client_transport_target() -> bool:
	if _adapter == null or _adapter.start_config == null:
		return false
	return _adapter.network_mode == _adapter.BattleNetworkMode.CLIENT \
		and String(_adapter.start_config.topology) == "dedicated_server" \
		and String(_adapter.start_config.session_mode) == "network_client" \
		and not String(_adapter.network_host).is_empty() \
		and int(_adapter.network_port) > 0
