class_name ClientRoomRuntime
extends Node

const RoomWsClientScript = preload("res://network/client_net/room/RoomWsClient.cs")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RoomDefaultsScript = preload("res://app/front/room/room_defaults.gd")
const RoomDirectorySnapshotScript = preload("res://network/session/room/model/room_directory_snapshot.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const MatchResumeSnapshotScript = preload("res://network/session/runtime/match_resume_snapshot.gd")
const ROOM_RUNTIME_DIRECTORY_TAG := "net.room_runtime.directory"
const ROOM_RUNTIME_ANOMALY_TAG := "net.room_runtime.anomaly"

signal transport_connected()
signal transport_disconnected()
signal room_snapshot_received(snapshot: RoomSnapshot)
signal room_directory_snapshot_received(snapshot: RoomDirectorySnapshot)
signal room_joined(snapshot: RoomSnapshot)
signal room_error(error_code: String, user_message: String)
signal canonical_start_config_received(config: BattleStartConfig)
signal battle_message_received(message: Dictionary)
signal match_loading_snapshot_received(snapshot: MatchLoadingSnapshot)

# LegacyMigration: Resume signals
signal room_member_session_received(payload: Dictionary)
signal match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot)

var _transport = null # compat/test-only transport adapter
var _allow_test_transport_fallback: bool = false
var _ws_client = null
var _last_snapshot: RoomSnapshot = null
var _connected: bool = false
var _connecting: bool = false
var _connected_host: String = ""
var _connected_port: int = 0
var _directory_subscribed: bool = false
var _pending_leave_disconnect: bool = false
var _leave_disconnect_deadline_msec: int = 0


func _process(_delta: float) -> void:
	var allow_transport_consume := _allow_test_transport_fallback and (_ws_client == null or not _connected)
	if allow_transport_consume and _transport != null and _transport.has_method("poll"):
		_transport.poll()
	if allow_transport_consume and _transport != null and _transport.has_method("consume_incoming"):
		for message in _transport.consume_incoming():
			_route_message(message)
	if _pending_leave_disconnect and Time.get_ticks_msec() >= _leave_disconnect_deadline_msec:
		_shutdown_transport()


func connect_to_server(host: String, port: int, timeout_sec: float = 5.0) -> void:
	var normalized_host := host.strip_edges() if not host.strip_edges().is_empty() else RoomDefaultsScript.DEFAULT_HOST
	var normalized_port := port if port > 0 else RoomDefaultsScript.DEFAULT_PORT
	if is_connected_to(normalized_host, normalized_port) and (_connected or _connecting):
		_log_directory_event("connect_reused_existing_transport", {
			"host": normalized_host,
			"port": normalized_port,
			"connected": _connected,
			"connecting": _connecting,
		})
		return
	_log_directory_event("connect_to_server", {
		"host": normalized_host,
		"port": normalized_port,
		"timeout_sec": timeout_sec,
	})
	_shutdown_transport()
	_allow_test_transport_fallback = false
	_connecting = true
	_connected_host = normalized_host
	_connected_port = normalized_port
	_ensure_ws_client()
	if _ws_client == null or not _ws_client.has_method("ConnectToServer"):
		_on_transport_error(-1, "RoomWsClient is unavailable")
		return
	var err = _ws_client.ConnectToServer(normalized_host, normalized_port)
	if int(err) != 0:
		_on_transport_error(int(err), "Room websocket connect failed")


func disconnect_from_server() -> void:
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	_shutdown_transport()


func inject_test_room_transport(adapter: Node) -> void:
	_transport = adapter
	_allow_test_transport_fallback = adapter != null
	if _allow_test_transport_fallback:
		_connect_transport_signals()


func is_transport_connected() -> bool:
	if _connected:
		return true
	if _transport != null and _transport.has_method("is_transport_connected"):
		return bool(_transport.is_transport_connected())
	return false


func is_connected_to(host: String, port: int) -> bool:
	var normalized_host := host.strip_edges() if not host.strip_edges().is_empty() else RoomDefaultsScript.DEFAULT_HOST
	var normalized_port := port if port > 0 else RoomDefaultsScript.DEFAULT_PORT
	return _connected_host == normalized_host and _connected_port == normalized_port


func request_create_room(
	room_id_hint: String,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	map_id: String = "",
	rule_set_id: String = "",
	mode_id: String = "",
	room_kind: String = "private_room",
	room_display_name: String = "",
	room_ticket: String = "",
	room_ticket_id: String = "",
	account_id: String = "",
	profile_id: String = "",
	device_session_id: String = ""
) -> void:
	_log_directory_event("request_create_room", {
		"room_id_hint": room_id_hint,
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"mode_id": mode_id,
	})
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"room_id_hint": room_id_hint,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"room_ticket": room_ticket,
		"room_ticket_id": room_ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
	})


func request_join_room(
	room_id_hint: String,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	room_ticket: String = "",
	room_ticket_id: String = "",
	account_id: String = "",
	profile_id: String = "",
	device_session_id: String = ""
) -> void:
	_log_directory_event("request_join_room", {
		"room_id_hint": room_id_hint,
		"player_name": player_name,
	})
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"room_id_hint": room_id_hint,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
		"room_ticket": room_ticket,
		"room_ticket_id": room_ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
	})


func request_update_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String,
	team_id: int
) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_PROFILE,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
		"team_id": team_id,
	})


func request_update_selection(map_id: String, rule_set_id: String, mode_id: String) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_SELECTION,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
	})


func request_update_match_room_config(match_format_id: String, selected_mode_ids: Array[String]) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_MATCH_ROOM_CONFIG,
		"match_format_id": match_format_id,
		"selected_mode_ids": selected_mode_ids.duplicate(),
	})


func request_enter_match_queue() -> void:
	LogNetScript.info("request_enter_match_queue sending ROOM_ENTER_MATCH_QUEUE", "", 0, "net.client_room_runtime")
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_ENTER_MATCH_QUEUE,
	})


func request_cancel_match_queue() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_CANCEL_MATCH_QUEUE,
	})


func request_battle_return() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_BATTLE_RETURN,
	})


func request_toggle_ready() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY,
	})


func request_start_match() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_START_REQUEST,
	})


func request_leave_room() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_LEAVE,
	})


func request_leave_room_and_disconnect() -> void:
	request_leave_room()
	if not is_transport_connected():
		_shutdown_transport()
		return
	_pending_leave_disconnect = true
	_leave_disconnect_deadline_msec = Time.get_ticks_msec() + 1500


func request_match_loading_ready(match_id: String, revision: int) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"match_id": match_id,
		"revision": revision,
		"sender_peer_id": _get_sender_peer_id(),
	})


func request_rematch() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_REMATCH_REQUEST,
		"sender_peer_id": _get_sender_peer_id(),
		"room_id_hint": _get_current_room_id_hint(),
	})


# LegacyMigration: Resume request
func request_resume_room(
	room_id: String,
	member_id: String,
	reconnect_token: String,
	match_id: String,
	room_ticket: String = "",
	room_ticket_id: String = "",
	account_id: String = "",
	profile_id: String = "",
	device_session_id: String = ""
) -> void:
	_log_directory_event("request_resume_room", {
		"room_id": room_id,
		"member_id": member_id,
		"match_id": match_id,
	})
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"room_id": room_id,
		"member_id": member_id,
		"reconnect_token": reconnect_token,
		"match_id": match_id,
		"room_ticket": room_ticket,
		"room_ticket_id": room_ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
		"sender_peer_id": _get_sender_peer_id(),
	})


func send_battle_input(message: Dictionary) -> void:
	_send_to_server(message)


func request_room_directory_snapshot() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_DIRECTORY_REQUEST,
	})


func subscribe_room_directory() -> void:
	_directory_subscribed = true
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_DIRECTORY_SUBSCRIBE,
	})


func unsubscribe_room_directory() -> void:
	_directory_subscribed = false
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_DIRECTORY_UNSUBSCRIBE,
	})


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	if not _transport.connected.is_connected(_on_transport_connected):
		_transport.connected.connect(_on_transport_connected)
	if not _transport.disconnected.is_connected(_on_transport_disconnected):
		_transport.disconnected.connect(_on_transport_disconnected)
	if not _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.connect(_on_transport_error)


func _route_message(message: Dictionary) -> void:
	if message.is_empty():
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type.is_empty():
		_log_room_anomaly("runtime_message_without_message_type", {
			"keys": message.keys(),
		})
		return
	match message_type:
		TransportMessageTypesScript.ROOM_CREATE_ACCEPTED:
			if _last_snapshot != null:
				room_joined.emit(_last_snapshot)
			else:
				_log_room_anomaly("create_accepted_without_snapshot", {
					"connected": _connected,
					"connecting": _connecting,
				})
		TransportMessageTypesScript.ROOM_CREATE_REJECTED:
			room_error.emit(String(message.get("error", "ROOM_CREATE_FAILED")), String(message.get("user_message", "Room create failed")))
		TransportMessageTypesScript.ROOM_JOIN_ACCEPTED:
			if _last_snapshot != null:
				room_joined.emit(_last_snapshot)
			else:
				_log_room_anomaly("join_accepted_without_snapshot", {
					"connected": _connected,
					"connecting": _connecting,
				})
		TransportMessageTypesScript.ROOM_JOIN_REJECTED:
			room_error.emit(String(message.get("error", "ROOM_JOIN_FAILED")), String(message.get("user_message", "Room join failed")))
		TransportMessageTypesScript.ROOM_LEAVE_ACCEPTED:
			if _pending_leave_disconnect:
				_shutdown_transport()
		TransportMessageTypesScript.ROOM_DIRECTORY_SNAPSHOT:
			var directory_snapshot := RoomDirectorySnapshotScript.from_dict(message.get("snapshot", {}))
			_log_directory_event("directory_snapshot_received", {
				"revision": int(directory_snapshot.revision),
				"entry_count": directory_snapshot.entries.size(),
				"server_host": String(directory_snapshot.server_host),
				"server_port": int(directory_snapshot.server_port),
			})
			room_directory_snapshot_received.emit(directory_snapshot)
		TransportMessageTypesScript.ROOM_SNAPSHOT:
			var snapshot := RoomSnapshot.from_dict(message.get("snapshot", {}))
			_sync_runtime_local_peer_id_from_snapshot(snapshot)
			if snapshot.room_id.is_empty():
				_log_room_anomaly("runtime_snapshot_without_room_id", {
					"message_type": message_type,
					"member_count": snapshot.members.size(),
					"topology": String(snapshot.topology),
				})
			if String(snapshot.topology) == "dedicated_server" and snapshot.members.is_empty():
				_log_room_anomaly("runtime_snapshot_without_members", {
					"message_type": message_type,
					"room_id": String(snapshot.room_id),
					"topology": String(snapshot.topology),
				})
			_last_snapshot = snapshot
			room_snapshot_received.emit(snapshot)
			room_joined.emit(snapshot)
		TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED:
			var config := BattleStartConfig.from_dict(message.get("start_config", {}))
			canonical_start_config_received.emit(config)
		TransportMessageTypesScript.JOIN_BATTLE_REJECTED:
			room_error.emit(String(message.get("error", "MATCH_START_REJECTED")), String(message.get("user_message", "Match start rejected")))
		TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
			var snapshot := MatchLoadingSnapshotScript.from_dict(message.get("snapshot", {}))
			match_loading_snapshot_received.emit(snapshot)
		TransportMessageTypesScript.ROOM_REMATCH_REJECTED:
			room_error.emit(String(message.get("error", "REMATCH_REJECTED")), String(message.get("user_message", "Rematch rejected")))
		"ROOM_UPDATE_PROFILE_REJECTED", \
		"ROOM_UPDATE_SELECTION_REJECTED", \
		"ROOM_UPDATE_MATCH_ROOM_CONFIG_REJECTED", \
		"ROOM_TOGGLE_READY_REJECTED", \
		"ROOM_START_REJECTED", \
		"ROOM_ENTER_MATCH_QUEUE_REJECTED", \
		"ROOM_CANCEL_MATCH_QUEUE_REJECTED", \
		"ROOM_ACK_BATTLE_ENTRY_REJECTED", \
		"ROOM_OPERATION_REJECTED":
			room_error.emit(String(message.get("error", "ROOM_OPERATION_REJECTED")), String(message.get("user_message", "Operation rejected")))
		TransportMessageTypesScript.ROOM_MATCH_QUEUE_STATUS:
			_apply_match_queue_status(message)
		TransportMessageTypesScript.ROOM_MATCH_ASSIGNMENT_READY:
			pass
		# LegacyMigration: Resume protocol messages
		TransportMessageTypesScript.ROOM_MEMBER_SESSION:
			room_member_session_received.emit(Dictionary(message).duplicate(true))
		TransportMessageTypesScript.ROOM_RESUME_REJECTED:
			room_error.emit(String(message.get("error", "ROOM_RESUME_REJECTED")), String(message.get("user_message", "Resume rejected")))
		TransportMessageTypesScript.MATCH_RESUME_ACCEPTED:
			var config := BattleStartConfig.from_dict(message.get("start_config", {}))
			var snapshot := MatchResumeSnapshotScript.from_dict(message.get("resume_snapshot", {}))
			match_resume_accepted.emit(config, snapshot)
		TransportMessageTypesScript.MATCH_RESUME_REJECTED:
			room_error.emit(String(message.get("error", "MATCH_RESUME_REJECTED")), String(message.get("user_message", "Match resume rejected")))
		TransportMessageTypesScript.INPUT_ACK, \
		TransportMessageTypesScript.STATE_SUMMARY, \
		TransportMessageTypesScript.CHECKPOINT, \
		TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, \
		TransportMessageTypesScript.MATCH_FINISHED:
			battle_message_received.emit(message)
		_:
			pass


func _apply_match_queue_status(message: Dictionary) -> void:
	var snapshot := _last_snapshot.duplicate_deep() if _last_snapshot != null else RoomSnapshot.new()
	snapshot.room_id = String(message.get("room_id", snapshot.room_id))
	snapshot.queue_type = String(message.get("queue_type", snapshot.queue_type))
	snapshot.match_format_id = String(message.get("match_format_id", snapshot.match_format_id))
	if message.has("selected_match_mode_ids"):
		snapshot.selected_match_mode_ids = RoomSnapshot.from_dict({
			"selected_match_mode_ids": message.get("selected_match_mode_ids", []),
		}).selected_match_mode_ids
	snapshot.required_party_size = int(message.get("required_party_size", snapshot.required_party_size))
	snapshot.room_queue_state = String(message.get("queue_state", snapshot.room_queue_state))
	snapshot.room_queue_entry_id = String(message.get("queue_entry_id", snapshot.room_queue_entry_id))
	snapshot.room_queue_status_text = String(message.get("queue_status_text", snapshot.room_queue_status_text))
	snapshot.room_queue_error_code = String(message.get("error_code", snapshot.room_queue_error_code))
	snapshot.room_queue_error_message = String(message.get("user_message", snapshot.room_queue_error_message))
	_last_snapshot = snapshot
	room_snapshot_received.emit(snapshot)


func _send_to_server(message: Dictionary) -> void:
	if _ws_client != null and _ws_client.has_method("SendMessage") and _connected:
		var send_error := int(_ws_client.SendMessage(message))
		if send_error == 0:
			return
		_log_room_anomaly("send_to_server_ws_failed", {
			"message_type": String(message.get("message_type", message.get("msg_type", ""))),
			"send_error": send_error,
		})
	if _allow_test_transport_fallback and _transport != null and _transport.has_method("is_transport_connected") and bool(_transport.is_transport_connected()):
		_transport.send_to_peer(1, message)
		return
	if _ws_client == null and (_transport == null or not _allow_test_transport_fallback):
		_log_room_anomaly("send_to_server_while_not_connected", {
			"message_type": String(message.get("message_type", message.get("msg_type", ""))),
			"has_transport": false,
			"has_ws_client": false,
			"connected": _connected,
			"connecting": _connecting,
		})
		room_error.emit("ROOM_CONNECT_FAILED", "Not connected to dedicated server")
		return
	if not _connected:
		room_error.emit("ROOM_CONNECT_FAILED", "Not connected to dedicated server")


func _on_transport_connected() -> void:
	_connected = true
	_connecting = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	transport_connected.emit()


func _on_transport_disconnected() -> void:
	_connected = false
	_connecting = false
	_directory_subscribed = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	var app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if app_runtime != null and app_runtime.has_method("set_local_peer_id"):
		app_runtime.set_local_peer_id(1)
	transport_disconnected.emit()


func _on_transport_error(_code: int, message: String) -> void:
	_connecting = false
	_log_room_anomaly("transport_error", {
		"message": message,
		"connected": _connected,
		"has_transport": _transport != null,
	})
	room_error.emit("ROOM_CONNECT_FAILED", message)


func _shutdown_transport() -> void:
	_connected = false
	_connecting = false
	_directory_subscribed = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	_last_snapshot = null
	if _ws_client != null and _ws_client.has_method("DisconnectFromServer"):
		_ws_client.DisconnectFromServer()
	if _ws_client != null:
		if _ws_client.get_parent() == self:
			remove_child(_ws_client)
		_ws_client.queue_free()
	_ws_client = null
	if _transport != null:
		if _transport.has_method("shutdown"):
			_transport.shutdown()
		if _transport.get_parent() == self:
			remove_child(_transport)
		_transport.queue_free()
	_transport = null
	_allow_test_transport_fallback = false
	_connected_host = ""
	_connected_port = 0


func _ensure_ws_client() -> void:
	if _ws_client != null:
		return
	_ws_client = RoomWsClientScript.new()
	add_child(_ws_client)
	_connect_ws_client_signals()


func _connect_ws_client_signals() -> void:
	if _ws_client == null:
		return
	if _ws_client.has_signal("Connected"):
		var callable := Callable(self, "_on_transport_connected")
		if not _ws_client.is_connected("Connected", callable):
			_ws_client.connect("Connected", callable)
	elif _ws_client.has_signal("connected"):
		var callable_lower := Callable(self, "_on_transport_connected")
		if not _ws_client.is_connected("connected", callable_lower):
			_ws_client.connect("connected", callable_lower)
	if _ws_client.has_signal("Disconnected"):
		var callable_disconnected := Callable(self, "_on_transport_disconnected")
		if not _ws_client.is_connected("Disconnected", callable_disconnected):
			_ws_client.connect("Disconnected", callable_disconnected)
	elif _ws_client.has_signal("disconnected"):
		var callable_disconnected_lower := Callable(self, "_on_transport_disconnected")
		if not _ws_client.is_connected("disconnected", callable_disconnected_lower):
			_ws_client.connect("disconnected", callable_disconnected_lower)
	if _ws_client.has_signal("RoomError"):
		var callable_error := Callable(self, "_on_ws_client_error")
		if not _ws_client.is_connected("RoomError", callable_error):
			_ws_client.connect("RoomError", callable_error)
	elif _ws_client.has_signal("room_error"):
		var callable_error_lower := Callable(self, "_on_ws_client_error")
		if not _ws_client.is_connected("room_error", callable_error_lower):
			_ws_client.connect("room_error", callable_error_lower)
	if _ws_client.has_signal("MessageReceived"):
		var callable_message := Callable(self, "_on_ws_client_message_received")
		if not _ws_client.is_connected("MessageReceived", callable_message):
			_ws_client.connect("MessageReceived", callable_message)
	elif _ws_client.has_signal("message_received"):
		var callable_message_lower := Callable(self, "_on_ws_client_message_received")
		if not _ws_client.is_connected("message_received", callable_message_lower):
			_ws_client.connect("message_received", callable_message_lower)


func _on_ws_client_error(error_code: String, user_message: String) -> void:
	_on_transport_error(-1, "%s: %s" % [error_code, user_message])


func _on_ws_client_message_received(payload: Dictionary) -> void:
	_route_message(Dictionary(payload).duplicate(true))


func _get_sender_peer_id() -> int:
	if _transport != null and _transport.has_method("get_local_peer_id"):
		return int(_transport.get_local_peer_id())
	return 1


const LogNetScript = preload("res://app/logging/log_net.gd")

func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	LogNetScript.warn("%s %s" % [event_name, JSON.stringify(details)], "", 0, ROOM_RUNTIME_ANOMALY_TAG)


func _log_directory_event(event_name: String, details: Dictionary) -> void:
	LogNetScript.debug("%s %s" % [event_name, JSON.stringify(details)], "", 0, ROOM_RUNTIME_DIRECTORY_TAG)


func _get_current_room_id_hint() -> String:
	if _last_snapshot != null:
		return String(_last_snapshot.room_id)
	return ""


func _sync_runtime_local_peer_id_from_snapshot(snapshot: RoomSnapshot) -> void:
	if snapshot == null:
		return
	var app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if app_runtime == null or not app_runtime.has_method("set_local_peer_id"):
		return
	var resolved_peer_id := 0
	for member in snapshot.members:
		if member != null and member.is_local_player and int(member.peer_id) > 0:
			resolved_peer_id = int(member.peer_id)
			break
	if resolved_peer_id <= 0 and snapshot.members.size() == 1:
		var only_member: RoomMemberState = snapshot.members[0]
		if only_member != null and int(only_member.peer_id) > 0:
			resolved_peer_id = int(only_member.peer_id)
	if resolved_peer_id <= 0:
		return
	app_runtime.set_local_peer_id(resolved_peer_id)
