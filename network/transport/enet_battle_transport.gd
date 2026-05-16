class_name ENetBattleTransport
extends IBattleTransport

const TransportMessageCodecScript = preload("res://network/transport/transport_message_codec.gd")
const BattleTransportChannelsScript = preload("res://network/transport/battle_transport_channels.gd")
const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const DEBUG_TRANSPORT_LOGS_DEFAULT: bool = false
const DEBUG_CLIENT_PACKET_PROBE_LOGS: bool = false
const DEFAULT_CONNECT_TIMEOUT_SECONDS: float = 5.0
const UNRELIABLE_PAYLOAD_SOFT_LIMIT_BYTES: int = BattleWireBudgetContractScript.UNRELIABLE_SOFT_LIMIT_BYTES
const MTU_PROMOTION_WARN_INTERVAL_MSEC: int = 3000
const HIGH_FREQ_LOG_FLUSH_INTERVAL_MSEC: int = 5000
const HIGH_FREQ_LOG_MESSAGE_TYPES: Array[String] = ["INPUT_BATCH", "STATE_SUMMARY", "STATE_DELTA", "CHECKPOINT"]

var _peer: ENetMultiplayerPeer = null
var _local_peer_id: int = 0
var _server_mode: bool = false
var _connected: bool = false
var _incoming_queue: Array[Dictionary] = []
var _remote_peer_ids: Array[int] = []
var _connect_timeout_seconds: float = DEFAULT_CONNECT_TIMEOUT_SECONDS
var _connect_started_msec: int = 0
var _connection_failure_reported: bool = false
var _last_logged_connection_status: int = -1
var _last_logged_connect_progress_sec: int = -1
var _last_client_packet_probe_msec: int = 0
var _target_host: String = ""
var _target_port: int = 0
var _sent_count_by_channel: Dictionary = {}
var _sent_bytes_by_channel: Dictionary = {}
var _sent_count_by_type: Dictionary = {}
var _max_payload_bytes_by_type: Dictionary = {}
var _payload_samples_by_type: Dictionary = {}
var _received_count_by_channel: Dictionary = {}
var _last_mtu_promotion_warn_msec_by_type: Dictionary = {}
var _unreliable_promoted_to_reliable_count: int = 0
var _unreliable_promoted_to_reliable_count_by_type: Dictionary = {}
var _last_promoted_payload_bytes_by_type: Dictionary = {}
var _high_freq_log_buckets: Dictionary = {}
var _high_freq_log_last_flush_msec: int = 0


func initialize(config: Dictionary = {}) -> void:
	shutdown()
	_server_mode = bool(config.get("is_server", false))
	_connect_timeout_seconds = max(float(config.get("connect_timeout_seconds", DEFAULT_CONNECT_TIMEOUT_SECONDS)), 0.5)
	_connection_failure_reported = false
	_connect_started_msec = 0
	_last_logged_connection_status = -1
	_last_logged_connect_progress_sec = -1
	_last_client_packet_probe_msec = 0
	_target_host = String(config.get("host", "127.0.0.1"))
	_target_port = int(config.get("port", 9000))
	_reset_transport_metrics()
	_peer = ENetMultiplayerPeer.new()
	var result := OK
	var channel_count := int(config.get("channel_count", BattleTransportChannelsScript.CHANNEL_COUNT))
	if _server_mode:
		result = _peer.create_server(
			int(config.get("port", 9000)),
			int(config.get("max_clients", 8)),
			channel_count,
			int(config.get("in_bandwidth", 0)),
			int(config.get("out_bandwidth", 0))
		)
		_connected = result == OK
	else:
		result = _peer.create_client(
			_target_host,
			_target_port,
			channel_count,
			int(config.get("in_bandwidth", 0)),
			int(config.get("out_bandwidth", 0)),
			int(config.get("local_port", 0))
		)
		_connected = false
		_connect_started_msec = Time.get_ticks_msec()
	if result != OK:
		_debug_log("initialize_failed mode=%s target=%s:%d result=%d" % [
			"server" if _server_mode else "client",
			_target_host,
			_target_port,
			result,
		])
		transport_error.emit(result, "Failed to initialize ENet transport")
		_peer = null
		_connected = false
		return
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_local_peer_id = _peer.get_unique_id() if _server_mode else 0
	if _connected:
		_remote_peer_ids = _read_peer_ids()
		_debug_log("initialized server listen_port=%d local=%d remote=%s" % [
			int(config.get("port", 9000)),
			_local_peer_id,
			str(_remote_peer_ids),
		])
		connected.emit()
	else:
		_debug_log("initialized client target=%s:%d timeout=%.2f channel_count=%d" % [
			_target_host,
			_target_port,
			_connect_timeout_seconds,
			channel_count,
		])


func shutdown(_context: Variant = null) -> void:
	if _peer != null:
		_debug_log("shutdown mode=%s connected=%s local=%d remote=%s target=%s:%d queued=%d" % [
			"server" if _server_mode else "client",
			str(_connected),
			_local_peer_id,
			str(_remote_peer_ids),
			_target_host,
			_target_port,
			_incoming_queue.size(),
		])
		_peer.close()
	_peer = null
	_incoming_queue.clear()
	_remote_peer_ids.clear()
	if _connected:
		disconnected.emit()
	_connected = false
	_local_peer_id = 0
	_connect_started_msec = 0
	_connection_failure_reported = false
	_last_logged_connection_status = -1
	_last_logged_connect_progress_sec = -1
	_last_client_packet_probe_msec = 0
	_target_host = ""
	_target_port = 0
	_reset_transport_metrics()
	_high_freq_log_buckets.clear()
	_high_freq_log_last_flush_msec = 0


func poll() -> void:
	if _peer == null:
		return
	if not _server_mode:
		var connection_status := _peer.get_connection_status()
		_log_client_connection_status_if_needed(connection_status)
		if not _connected and connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_report_connection_failure(ERR_CANT_CONNECT, "Failed to connect to server")
			_cleanup_failed_connection()
			return
		if not _connected and connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
			var elapsed_seconds := float(Time.get_ticks_msec() - _connect_started_msec) / 1000.0
			_log_client_connect_progress_if_needed(elapsed_seconds)
			if elapsed_seconds >= _connect_timeout_seconds:
				_report_connection_failure(ERR_TIMEOUT, "Connection timed out")
				_cleanup_failed_connection()
				return
	if _peer.has_method("poll"):
		_peer.call("poll")
	_log_client_packet_probe_if_needed()
	_sync_connection_state()
	_sync_remote_peer_ids()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var packet_channel := _peer.get_packet_channel()
		var packet_mode := _peer.get_packet_mode()
		var sender_peer_id := _peer.get_packet_peer()
		var payload: PackedByteArray = _peer.get_packet()
		_ensure_remote_peer_known(sender_peer_id)
		var message := TransportMessageCodecScript.decode_message(payload)
		if message.is_empty():
			_debug_log("received undecodable packet from %d" % sender_peer_id)
			continue
		message["sender_peer_id"] = sender_peer_id
		message["transport_channel"] = packet_channel
		message["transport_mode"] = packet_mode
		_increment_metric(_received_count_by_channel, packet_channel, 1)
		_incoming_queue.append(message)
		_log_event_probe("transport_recv", sender_peer_id, message, payload.size())
		var recv_message_type := _message_type(message)
		if recv_message_type.is_empty():
			recv_message_type = "unknown"
		if _is_high_freq_message_type(recv_message_type):
			_high_freq_log_record("received", recv_message_type, payload.size())
		else:
			_debug_log("received %s from %d" % [recv_message_type, sender_peer_id])
	_high_freq_log_flush_if_due()


func is_server() -> bool:
	return _server_mode


func is_transport_connected() -> bool:
	return _connected


func get_local_peer_id() -> int:
	return _local_peer_id


func get_remote_peer_ids() -> Array[int]:
	return _remote_peer_ids.duplicate()


func send_to_peer(peer_id: int, message: Dictionary) -> void:
	if _peer == null or peer_id <= 0:
		return
	if peer_id == _local_peer_id:
		return
	var message_type := _message_type(message)
	_log_event_probe("transport_send", peer_id, message, 0)
	var payload := TransportMessageCodecScript.encode_message(message)
	_send_payload_to_peer(peer_id, payload, message_type)
	_high_freq_log_flush_if_due()


func broadcast(message: Dictionary) -> void:
	if _peer == null:
		return
	if _remote_peer_ids.is_empty():
		return
	var message_type := _message_type(message)
	if _is_high_freq_message_type(message_type):
		_high_freq_log_record("broadcast", message_type, 0)
	else:
		_debug_log("broadcast %s -> %s" % [message_type, str(_remote_peer_ids)])
	for peer_id in _remote_peer_ids.duplicate():
		_log_event_probe("transport_broadcast", peer_id, message, 0)
	var payload := TransportMessageCodecScript.encode_message(message)
	for peer_id in _remote_peer_ids.duplicate():
		_send_payload_to_peer(peer_id, payload, message_type)
	_high_freq_log_flush_if_due()


func consume_incoming() -> Array[Dictionary]:
	var messages := _incoming_queue.duplicate(true)
	_incoming_queue.clear()
	return messages


func get_transport_metrics() -> Dictionary:
	return {
		"sent_count_by_channel": _sent_count_by_channel.duplicate(true),
		"sent_bytes_by_channel": _sent_bytes_by_channel.duplicate(true),
		"sent_count_by_type": _sent_count_by_type.duplicate(true),
		"max_payload_bytes_by_type": _max_payload_bytes_by_type.duplicate(true),
		"p95_payload_bytes_by_type": _build_p95_payload_bytes_by_type(),
		"received_count_by_channel": _received_count_by_channel.duplicate(true),
		"unreliable_promoted_to_reliable_count": _unreliable_promoted_to_reliable_count,
		"transport_unreliable_promoted_to_reliable_count": _unreliable_promoted_to_reliable_count,
		"unreliable_promoted_to_reliable_count_by_type": _unreliable_promoted_to_reliable_count_by_type.duplicate(true),
		"last_promoted_payload_bytes_by_type": _last_promoted_payload_bytes_by_type.duplicate(true),
	}


func _sync_connection_state() -> void:
	var connected_now := _connected
	if _server_mode:
		connected_now = _peer != null
	else:
		connected_now = _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if connected_now and not _connected:
		_connected = true
		_connection_failure_reported = false
		_local_peer_id = _peer.get_unique_id()
		_debug_log("connected_to_server target=%s:%d local=%d peers=%s" % [
			_target_host,
			_target_port,
			_local_peer_id,
			str(_read_peer_ids()),
		])
		connected.emit()
	elif not connected_now and _connected:
		_connected = false
		_remote_peer_ids.clear()
		_debug_log("disconnected target=%s:%d local=%d" % [
			_target_host,
			_target_port,
			_local_peer_id,
		])
		disconnected.emit()


func _sync_remote_peer_ids() -> void:
	var next_peer_ids := _read_peer_ids()
	for peer_id in next_peer_ids:
		_ensure_remote_peer_known(peer_id)
	if _server_mode:
		return
	var removed_peer_ids: Array[int] = []
	for peer_id in _remote_peer_ids:
		if next_peer_ids.has(peer_id):
			continue
		if peer_id == 1 and _connected:
			continue
		removed_peer_ids.append(peer_id)
	for peer_id in removed_peer_ids:
		_remove_remote_peer(peer_id, "peer_list_sync")


func _read_peer_ids() -> Array[int]:
	if _peer == null:
		return []
	if _server_mode:
		var peers_variant: Variant = []
		if _peer.has_method("get_peers"):
			peers_variant = _peer.call("get_peers")
		return _sanitize_peer_ids(peers_variant if peers_variant is Array else [])
	if _connected:
		return [1]
	return []


func _sanitize_peer_ids(peer_ids: Array) -> Array[int]:
	var sanitized: Array[int] = []
	for peer_id in peer_ids:
		var resolved_peer_id := int(peer_id)
		if resolved_peer_id <= 0 or resolved_peer_id == _local_peer_id:
			continue
		if not sanitized.has(resolved_peer_id):
			sanitized.append(resolved_peer_id)
	sanitized.sort()
	return sanitized


func _ensure_remote_peer_known(peer_id: int) -> void:
	if peer_id <= 0 or peer_id == _local_peer_id:
		return
	if _remote_peer_ids.has(peer_id):
		return
	_remote_peer_ids.append(peer_id)
	_remote_peer_ids.sort()
	_debug_log("peer_connected local=%d remote=%d peers=%s" % [_local_peer_id, peer_id, str(_remote_peer_ids)])
	peer_connected.emit(peer_id)


func _remove_remote_peer(peer_id: int, reason: String) -> void:
	if not _remote_peer_ids.has(peer_id):
		return
	_remote_peer_ids.erase(peer_id)
	_debug_log("peer_disconnected local=%d remote=%d reason=%s peers=%s" % [
		_local_peer_id,
		peer_id,
		reason,
		str(_remote_peer_ids),
	])
	peer_disconnected.emit(peer_id)


func _send_payload_to_peer(peer_id: int, payload: PackedByteArray, message_type: String) -> void:
	if _peer == null or peer_id <= 0:
		return
	if peer_id == _local_peer_id:
		return
	_peer.transfer_channel = BattleTransportChannelsScript.resolve_channel(message_type)
	_peer.transfer_mode = BattleTransportChannelsScript.resolve_transfer_mode(message_type)
	_record_payload_size(message_type, payload.size())
	if _peer.transfer_mode != MultiplayerPeer.TRANSFER_MODE_RELIABLE and payload.size() > UNRELIABLE_PAYLOAD_SOFT_LIMIT_BYTES:
		_unreliable_promoted_to_reliable_count += 1
		_increment_metric(_unreliable_promoted_to_reliable_count_by_type, message_type, 1)
		_last_promoted_payload_bytes_by_type[message_type] = payload.size()
		_log_mtu_promotion_if_needed(message_type, payload.size(), peer_id)
		_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.set_target_peer(peer_id)
	var result := _peer.put_packet(payload)
	var resolved_channel: int = _peer.transfer_channel
	var resolved_mode: int = _peer.transfer_mode
	if result == OK:
		_increment_metric(_sent_count_by_channel, resolved_channel, 1)
		_increment_metric(_sent_bytes_by_channel, resolved_channel, payload.size())
		_increment_metric(_sent_count_by_type, message_type, 1)
	if result == OK and _is_high_freq_message_type(message_type):
		_high_freq_log_record("send", message_type, payload.size())
	else:
		_debug_log("send %s -> %d channel=%d mode=%d result=%d" % [
			message_type,
			peer_id,
			resolved_channel,
			resolved_mode,
			result,
		])
	if result != OK:
		LogNetScript.warn(
			"transport_send_failed message_type=%s peer=%d channel=%d mode=%d result=%d payload_bytes=%d connection_status=%s remote_peers=%s server_mode=%s local_peer=%d" % [
				message_type,
				peer_id,
				resolved_channel,
				resolved_mode,
				result,
				payload.size(),
				_connection_status_name(_peer.get_connection_status()),
				str(_remote_peer_ids),
				str(_server_mode),
				_local_peer_id,
			],
			"",
			0,
			"net.transport"
		)
		if result == ERR_INVALID_PARAMETER and _remote_peer_ids.has(peer_id):
			_remove_remote_peer(peer_id, "send_invalid_peer")
		transport_error.emit(result, "ENet transport failed to send packet")


func _message_type(message: Dictionary) -> String:
	return String(message.get("message_type", ""))


func _log_event_probe(stage: String, peer_id: int, message: Dictionary, payload_bytes: int) -> void:
	var events := _explosion_events_from_message(message)
	if events.is_empty():
		return
	for event in events:
		var payload: Dictionary = (event as Dictionary).get("payload", {})
		var covered_cells: Array = payload.get("covered_cells", [])
		LogNetScript.info(
			"QQT_EXPLOSION_TRACE stage=%s peer=%d message_type=%s tick=%d event_tick=%d bubble_id=%d owner=%d cell=(%d,%d) covered_cells=%d payload_bytes=%d payload_keys=%s" % [
				stage,
				peer_id,
				_message_type(message),
				int(message.get("tick", -1)),
				int((event as Dictionary).get("tick", -1)),
				int(payload.get("bubble_id", payload.get("entity_id", -1))),
				int(payload.get("owner_player_id", -1)),
				int(payload.get("cell_x", -1)),
				int(payload.get("cell_y", -1)),
				covered_cells.size(),
				payload_bytes,
				str(payload.keys()),
			],
			"",
			0,
			"net.transport.explosion"
		)


func _explosion_events_from_message(message: Dictionary) -> Array:
	var source: Variant = message.get("events", [])
	if not (source is Array) or (source as Array).is_empty():
		source = message.get("event_details", [])
	if not (source is Array):
		return []
	var result: Array = []
	for event in source:
		if not (event is Dictionary):
			continue
		if int((event as Dictionary).get("event_type", -1)) == 3:
			result.append(event)
	return result


func _increment_metric(metrics: Dictionary, key: Variant, amount: int) -> void:
	metrics[key] = int(metrics.get(key, 0)) + amount


func _reset_transport_metrics() -> void:
	_sent_count_by_channel.clear()
	_sent_bytes_by_channel.clear()
	_sent_count_by_type.clear()
	_max_payload_bytes_by_type.clear()
	_payload_samples_by_type.clear()
	_received_count_by_channel.clear()
	_last_mtu_promotion_warn_msec_by_type.clear()
	_unreliable_promoted_to_reliable_count = 0
	_unreliable_promoted_to_reliable_count_by_type.clear()
	_last_promoted_payload_bytes_by_type.clear()


func _record_payload_size(message_type: String, payload_size: int) -> void:
	_max_payload_bytes_by_type[message_type] = max(int(_max_payload_bytes_by_type.get(message_type, 0)), payload_size)
	var samples: Array = _payload_samples_by_type.get(message_type, [])
	samples.append(payload_size)
	if samples.size() > 128:
		samples.remove_at(0)
	_payload_samples_by_type[message_type] = samples


func _build_p95_payload_bytes_by_type() -> Dictionary:
	var result: Dictionary = {}
	for message_type in _payload_samples_by_type.keys():
		var samples: Array = (_payload_samples_by_type[message_type] as Array).duplicate()
		if samples.is_empty():
			continue
		samples.sort()
		var index := clampi(int(ceil(float(samples.size()) * 0.95)) - 1, 0, samples.size() - 1)
		result[message_type] = int(samples[index])
	return result


func get_shutdown_name() -> String:
	return "enet_battle_transport"


func get_shutdown_priority() -> int:
	return 50


func get_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"connected": _connected,
		"queued_incoming": _incoming_queue.size(),
	}


func _log_mtu_promotion_if_needed(message_type: String, payload_size: int, peer_id: int) -> void:
	var now_msec := Time.get_ticks_msec()
	var last_msec := int(_last_mtu_promotion_warn_msec_by_type.get(message_type, -MTU_PROMOTION_WARN_INTERVAL_MSEC))
	if now_msec - last_msec < MTU_PROMOTION_WARN_INTERVAL_MSEC:
		return
	_last_mtu_promotion_warn_msec_by_type[message_type] = now_msec
	LogNetScript.warn("battle unreliable payload promoted to reliable type=%s bytes=%d peer=%d" % [
		message_type,
		payload_size,
		peer_id,
	], "", 0, "net.battle_transport.mtu")


func _report_connection_failure(code: int, message: String) -> void:
	if _connection_failure_reported:
		return
	_connection_failure_reported = true
	transport_error.emit(code, message)
	_debug_log("connection_failure target=%s:%d code=%d message=%s status=%s elapsed=%.2f" % [
		_target_host,
		_target_port,
		code,
		message,
		_connection_status_name(_peer.get_connection_status() if _peer != null else -1),
		float(Time.get_ticks_msec() - _connect_started_msec) / 1000.0 if _connect_started_msec > 0 else -1.0,
	])


func _cleanup_failed_connection() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_remote_peer_ids.clear()
	_incoming_queue.clear()
	_connected = false
	_local_peer_id = 0
	_last_logged_connection_status = -1
	_last_logged_connect_progress_sec = -1


func _log_client_connection_status_if_needed(connection_status: int) -> void:
	if _server_mode:
		return
	if connection_status == _last_logged_connection_status:
		return
	_last_logged_connection_status = connection_status
	_debug_log("client_connection_status=%s elapsed=%.2f target_peers=%s" % [
		_connection_status_name(connection_status),
		float(Time.get_ticks_msec() - _connect_started_msec) / 1000.0 if _connect_started_msec > 0 else -1.0,
		str(_remote_peer_ids),
	])


func _log_client_connect_progress_if_needed(elapsed_seconds: float) -> void:
	if _server_mode:
		return
	var elapsed_bucket: int = int(floor(elapsed_seconds))
	if elapsed_bucket == _last_logged_connect_progress_sec:
		return
	_last_logged_connect_progress_sec = elapsed_bucket
	_debug_log("client_connecting_progress target=%s:%d elapsed=%.2f timeout=%.2f peers=%s" % [
		_target_host,
		_target_port,
		elapsed_seconds,
		_connect_timeout_seconds,
		str(_remote_peer_ids),
	])


func _log_client_packet_probe_if_needed() -> void:
	if not DEBUG_CLIENT_PACKET_PROBE_LOGS:
		return
	if _server_mode or _peer == null:
		return
	var now := Time.get_ticks_msec()
	var available := _peer.get_available_packet_count()
	if available <= 0 and now - _last_client_packet_probe_msec < 1000:
		return
	_last_client_packet_probe_msec = now
	_debug_log("client_packet_probe target=%s:%d status=%s available=%d connected=%s local=%d peers=%s" % [
		_target_host,
		_target_port,
		_connection_status_name(_peer.get_connection_status()),
		available,
		str(_connected),
		_local_peer_id,
		str(_remote_peer_ids),
	])


func _connection_status_name(connection_status: int) -> String:
	match connection_status:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "DISCONNECTED"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "CONNECTING"
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "CONNECTED"
		_:
			return "UNKNOWN_%d" % connection_status


func _debug_log(message: String) -> void:
	if not _is_debug_transport_logs_enabled():
		return
	LogNetScript.debug(message, "", 0, "net.transport")


func _is_high_freq_message_type(message_type: String) -> bool:
	return HIGH_FREQ_LOG_MESSAGE_TYPES.has(message_type)


func _high_freq_log_record(direction: String, message_type: String, payload_bytes: int) -> void:
	if not _is_debug_transport_logs_enabled():
		return
	var key := direction + "|" + message_type
	var bucket: Dictionary = _high_freq_log_buckets.get(key, {
		"direction": direction,
		"message_type": message_type,
		"count": 0,
		"bytes_sum": 0,
		"bytes_max": 0,
	})
	bucket["count"] = int(bucket.get("count", 0)) + 1
	bucket["bytes_sum"] = int(bucket.get("bytes_sum", 0)) + payload_bytes
	if payload_bytes > int(bucket.get("bytes_max", 0)):
		bucket["bytes_max"] = payload_bytes
	_high_freq_log_buckets[key] = bucket
	if _high_freq_log_last_flush_msec == 0:
		_high_freq_log_last_flush_msec = Time.get_ticks_msec()


func _high_freq_log_flush_if_due() -> void:
	if not _is_debug_transport_logs_enabled():
		return
	if _high_freq_log_buckets.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _high_freq_log_last_flush_msec == 0:
		_high_freq_log_last_flush_msec = now
		return
	if now - _high_freq_log_last_flush_msec < HIGH_FREQ_LOG_FLUSH_INTERVAL_MSEC:
		return
	var window_msec: int = max(1, now - _high_freq_log_last_flush_msec)
	for key in _high_freq_log_buckets.keys():
		var bucket: Dictionary = _high_freq_log_buckets[key]
		var count := int(bucket.get("count", 0))
		if count <= 0:
			continue
		var bytes_sum := int(bucket.get("bytes_sum", 0))
		var bytes_avg := int(bytes_sum / count) if count > 0 else 0
		LogNetScript.debug(
			"transport_high_freq_summary direction=%s message_type=%s window_msec=%d count=%d bytes_avg=%d bytes_max=%d" % [
				String(bucket.get("direction", "")),
				String(bucket.get("message_type", "")),
				window_msec,
				count,
				bytes_avg,
				int(bucket.get("bytes_max", 0)),
			],
			"",
			0,
			"net.transport"
		)
	_high_freq_log_buckets.clear()
	_high_freq_log_last_flush_msec = now


func _is_debug_transport_logs_enabled() -> bool:
	var value := OS.get_environment("QQT_DEBUG_TRANSPORT_LOGS").strip_edges().to_lower()
	if value == "1" or value == "true" or value == "yes" or value == "on":
		return true
	if value == "0" or value == "false" or value == "no" or value == "off":
		return false
	return DEBUG_TRANSPORT_LOGS_DEFAULT
