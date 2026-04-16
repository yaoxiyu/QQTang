class_name ServerRoomRegistry
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomAuthorityRuntimeScript = preload("res://network/session/runtime/room_authority_runtime.gd")
const RoomDirectorySnapshotScript = preload("res://network/session/runtime/room_directory_snapshot.gd")
const ROOM_REGISTRY_DIRECTORY_TAG := "session.room_registry.directory"

const ROOM_DIRECTORY_REQUEST := "ROOM_DIRECTORY_REQUEST"
const ROOM_DIRECTORY_SUBSCRIBE := "ROOM_DIRECTORY_SUBSCRIBE"
const ROOM_DIRECTORY_UNSUBSCRIBE := "ROOM_DIRECTORY_UNSUBSCRIBE"
const ROOM_DIRECTORY_SNAPSHOT := "ROOM_DIRECTORY_SNAPSHOT"

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)

var room_runtimes: Dictionary = {}
var peer_room_bindings: Dictionary = {}
var directory_subscribers: Dictionary = {}
var directory_revision: int = 0
var authority_host: String = "127.0.0.1"
var authority_port: int = 9000
var room_ticket_secret: String = "dev_room_ticket_secret"


func route_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	var sender_peer_id := int(message.get("sender_peer_id", 0))
	match message_type:
		ROOM_DIRECTORY_REQUEST:
			if sender_peer_id > 0:
				_log_directory_event("directory_request", {"peer_id": sender_peer_id})
				send_directory_snapshot_to(sender_peer_id)
		ROOM_DIRECTORY_SUBSCRIBE:
			if sender_peer_id > 0:
				directory_subscribers[sender_peer_id] = true
				_log_directory_event("directory_subscribe", {"peer_id": sender_peer_id, "subscriber_count": directory_subscribers.size()})
				send_directory_snapshot_to(sender_peer_id)
		ROOM_DIRECTORY_UNSUBSCRIBE:
			if sender_peer_id > 0:
				directory_subscribers.erase(sender_peer_id)
				_log_directory_event("directory_unsubscribe", {"peer_id": sender_peer_id, "subscriber_count": directory_subscribers.size()})
		TransportMessageTypesScript.ROOM_CREATE_REQUEST:
			_route_create_room_message(message)
		TransportMessageTypesScript.ROOM_JOIN_REQUEST:
			_route_join_room_message(message)
		TransportMessageTypesScript.ROOM_RESUME_REQUEST:
			_route_resume_room_message(message)
		TransportMessageTypesScript.ROOM_UPDATE_PROFILE, \
		TransportMessageTypesScript.ROOM_UPDATE_SELECTION, \
		TransportMessageTypesScript.ROOM_UPDATE_MATCH_ROOM_CONFIG, \
		TransportMessageTypesScript.ROOM_ENTER_MATCH_QUEUE, \
		TransportMessageTypesScript.ROOM_CANCEL_MATCH_QUEUE, \
		TransportMessageTypesScript.ROOM_TOGGLE_READY, \
		TransportMessageTypesScript.ROOM_START_REQUEST, \
		TransportMessageTypesScript.ROOM_LEAVE, \
		TransportMessageTypesScript.ROOM_REMATCH_REQUEST:
			_route_bound_room_message(message)
		_:
			pass


func handle_peer_disconnected(peer_id: int) -> void:
	if peer_id <= 0:
		return
	_log_directory_event("peer_disconnected", {
		"peer_id": peer_id,
		"bound_room_id": String(peer_room_bindings.get(peer_id, "")),
	})
	directory_subscribers.erase(peer_id)
	var room_id := String(peer_room_bindings.get(peer_id, ""))
	if room_id.is_empty():
		return
	var runtime = room_runtimes.get(room_id, null)
	if runtime != null:
		runtime.handle_peer_disconnected(peer_id)
	peer_room_bindings.erase(peer_id)
	_reconcile_runtime_bindings(room_id, runtime)


func build_directory_snapshot() -> RoomDirectorySnapshot:
	var snapshot := RoomDirectorySnapshotScript.new()
	snapshot.revision = directory_revision
	snapshot.server_host = authority_host
	snapshot.server_port = authority_port
	var room_ids: Array[String] = []
	for room_id_variant in room_runtimes.keys():
		room_ids.append(String(room_id_variant))
	room_ids.sort()
	for room_id in room_ids:
		var runtime = room_runtimes.get(room_id, null)
		if runtime == null:
			continue
		var entry = runtime.build_directory_entry()
		if entry != null:
			snapshot.entries.append(entry)
	return snapshot


func broadcast_directory_snapshot() -> void:
	directory_revision += 1
	var snapshot := build_directory_snapshot()
	_log_directory_event("broadcast_directory_snapshot", {
		"revision": directory_revision,
		"entry_count": snapshot.entries.size(),
		"subscriber_count": directory_subscribers.size(),
	})
	var payload := {
		"message_type": ROOM_DIRECTORY_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	}
	for peer_id_variant in directory_subscribers.keys():
		var peer_id := int(peer_id_variant)
		if peer_id > 0:
			send_to_peer.emit(peer_id, payload)


func send_directory_snapshot_to(peer_id: int) -> void:
	if peer_id <= 0:
		return
	var snapshot := build_directory_snapshot()
	send_to_peer.emit(peer_id, {
		"message_type": ROOM_DIRECTORY_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	})


func _route_create_room_message(message: Dictionary) -> void:
	var runtime = _create_room_runtime()
	var create_result: Dictionary = runtime.create_room_from_request(message)
	var room_id := String(create_result.get("room_id", ""))
	var owner_peer_id := int(create_result.get("owner_peer_id", 0))
	if room_id.is_empty() or owner_peer_id <= 0:
		_destroy_runtime(runtime)
		return
	room_runtimes[room_id] = runtime
	peer_room_bindings[owner_peer_id] = room_id
	_log_directory_event("room_created", {
		"room_id": room_id,
		"owner_peer_id": owner_peer_id,
		"room_kind": String(create_result.get("room_kind", "")),
		"runtime_count": room_runtimes.size(),
	})
	broadcast_directory_snapshot()


func _route_join_room_message(message: Dictionary) -> void:
	var room_id_hint := String(message.get("room_id_hint", "")).strip_edges()
	var peer_id := int(message.get("sender_peer_id", 0))
	if room_id_hint.is_empty():
		return
	var runtime = room_runtimes.get(room_id_hint, null)
	if runtime == null:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Target room does not exist",
		})
		return
	runtime.handle_room_message(message)
	if peer_id > 0 and runtime.has_peer(peer_id):
		peer_room_bindings[peer_id] = room_id_hint
		_log_directory_event("room_joined", {
			"room_id": room_id_hint,
			"peer_id": peer_id,
		})
	_reconcile_runtime_bindings(room_id_hint, runtime)


func _route_resume_room_message(message: Dictionary) -> void:
	var requested_room_id := String(message.get("room_id", "")).strip_edges()
	var peer_id := int(message.get("sender_peer_id", 0))
	var member_id := String(message.get("member_id", "")).strip_edges()
	var reconnect_token := String(message.get("reconnect_token", "")).strip_edges()
	_log_directory_event("resume_request", {
		"requested_room_id": requested_room_id,
		"peer_id": peer_id,
		"member_id": member_id,
		"match_id": String(message.get("match_id", "")),
		"runtime_count": room_runtimes.size(),
	})
	var runtime = room_runtimes.get(requested_room_id, null)
	var resolved_room_id := requested_room_id
	if runtime == null:
		runtime = _find_resume_runtime(member_id, reconnect_token)
		if runtime != null:
			resolved_room_id = runtime.get_room_id()
			_log_directory_event("resume_room_id_repaired", {
				"requested_room_id": requested_room_id,
				"resolved_room_id": resolved_room_id,
				"peer_id": peer_id,
				"member_id": member_id,
			})
	if runtime == null:
		_log_directory_event("resume_rejected_room_not_found", {
			"requested_room_id": requested_room_id,
			"peer_id": peer_id,
			"member_id": member_id,
			"known_room_ids": _sorted_room_ids(),
		})
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_RESUME_REJECTED,
			"error": "ROOM_NOT_FOUND",
			"user_message": "Target room does not exist",
		})
		return
	var routed_message := message.duplicate(true)
	routed_message["room_id"] = resolved_room_id
	runtime.handle_room_message(routed_message)
	if peer_id > 0 and runtime.has_peer(peer_id):
		peer_room_bindings[peer_id] = resolved_room_id
		_log_directory_event("room_resumed", {
			"room_id": resolved_room_id,
			"requested_room_id": requested_room_id,
			"peer_id": peer_id,
			"member_id": member_id,
		})
	_reconcile_runtime_bindings(resolved_room_id, runtime)


func _route_bound_room_message(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	var room_id := String(peer_room_bindings.get(peer_id, ""))
	if room_id.is_empty():
		_log_directory_event("route_bound_no_binding", {"peer_id": peer_id, "message_type": message_type})
		return
	var runtime = room_runtimes.get(room_id, null)
	if runtime == null:
		_log_directory_event("route_bound_no_runtime", {"peer_id": peer_id, "room_id": room_id, "message_type": message_type})
		peer_room_bindings.erase(peer_id)
		return
	_log_directory_event("route_bound_dispatching", {"peer_id": peer_id, "room_id": room_id, "message_type": message_type})
	runtime.handle_room_message(message)
	if not runtime.has_peer(peer_id):
		peer_room_bindings.erase(peer_id)
	_reconcile_runtime_bindings(room_id, runtime)


func _create_room_runtime():
	# Phase23: Create RoomAuthorityRuntime instead of mixed ServerRoomRuntime
	var runtime = RoomAuthorityRuntimeScript.new()
	runtime.name = "RoomAuthorityRuntime_%d" % int(Time.get_ticks_usec() % 1000000)
	add_child(runtime)
	runtime.configure(authority_host, authority_port, room_ticket_secret)
	_connect_runtime_signals(runtime)
	return runtime


func _connect_runtime_signals(runtime) -> void:
	if runtime == null:
		return
	var send_callable := Callable(self, "_on_runtime_send_to_peer").bind(runtime)
	if not runtime.send_to_peer.is_connected(send_callable):
		runtime.send_to_peer.connect(send_callable)
	var broadcast_callable := Callable(self, "_on_runtime_broadcast_message").bind(runtime)
	if not runtime.broadcast_message.is_connected(broadcast_callable):
		runtime.broadcast_message.connect(broadcast_callable)


func _on_runtime_send_to_peer(peer_id: int, message: Dictionary, _runtime) -> void:
	send_to_peer.emit(peer_id, message)


func _on_runtime_broadcast_message(message: Dictionary, runtime) -> void:
	# Phase23: Only send to members of this room, not all connected peers
	var room_state = runtime.get_room_state() if runtime != null and runtime.has_method("get_room_state") else null
	if room_state != null and room_state.members != null:
		for peer_id in room_state.members.keys():
			send_to_peer.emit(int(peer_id), message)
	else:
		broadcast_message.emit(message)
	var room_id: String = runtime.get_room_id() if runtime != null else ""
	_reconcile_runtime_bindings(room_id, runtime)
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.ROOM_SNAPSHOT:
		if not room_id.is_empty() and not room_runtimes.has(room_id):
			return
		broadcast_directory_snapshot()
	elif message_type == TransportMessageTypesScript.MATCH_FINISHED:
		broadcast_directory_snapshot()


func _reconcile_runtime_bindings(room_id: String, runtime) -> void:
	if room_id.is_empty() or runtime == null:
		return
	if runtime.is_empty():
		_remove_bindings_for_room(room_id)
		_destroy_runtime(runtime, room_id)


func _remove_bindings_for_room(room_id: String) -> void:
	var bound_peer_ids: Array[int] = []
	for peer_id_variant in peer_room_bindings.keys():
		var peer_id := int(peer_id_variant)
		if String(peer_room_bindings.get(peer_id_variant, "")) == room_id:
			bound_peer_ids.append(peer_id)
	for peer_id in bound_peer_ids:
		peer_room_bindings.erase(peer_id)


func _find_resume_runtime(member_id: String, reconnect_token: String):
	var normalized_member_id := member_id.strip_edges()
	var normalized_token := reconnect_token.strip_edges()
	if normalized_member_id.is_empty() or normalized_token.is_empty():
		return null
	for room_id in _sorted_room_ids():
		var runtime = room_runtimes.get(room_id, null)
		if runtime != null and runtime.can_route_resume_request(normalized_member_id, normalized_token):
			return runtime
	return null


func _sorted_room_ids() -> Array[String]:
	var room_ids: Array[String] = []
	for room_id_variant in room_runtimes.keys():
		room_ids.append(String(room_id_variant))
	room_ids.sort()
	return room_ids


func _destroy_runtime(runtime, room_id: String = "") -> void:
	if runtime == null:
		return
	var resolved_room_id: String = room_id if not room_id.is_empty() else runtime.get_room_id()
	_log_directory_event("room_runtime_destroyed", {
		"room_id": resolved_room_id,
		"runtime_count_before": room_runtimes.size(),
	})
	if not resolved_room_id.is_empty():
		room_runtimes.erase(resolved_room_id)
	if runtime.get_parent() == self:
		remove_child(runtime)
	runtime.queue_free()


const LogSessionScript = preload("res://app/logging/log_session.gd")

func _log_directory_event(event_name: String, payload: Dictionary) -> void:
	LogSessionScript.debug("%s %s" % [event_name, JSON.stringify(payload)], "", 0, ROOM_REGISTRY_DIRECTORY_TAG)
