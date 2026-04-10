extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := true
	ok = _test_registry_tracks_room_bindings_and_directory_entries() and ok
	ok = _test_directory_subscriber_receives_public_room_after_create() and ok
	ok = _test_registry_routes_idle_room_resume_request() and ok
	ok = _test_registry_repairs_stale_idle_resume_room_id() and ok
	ok = _test_registry_rebinds_active_match_resume_transport() and ok
	ok = _test_registry_repairs_stale_active_resume_room_id() and ok
	if ok:
		print("server_room_registry_test: PASS")


func _test_registry_tracks_room_bindings_and_directory_entries() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)

	registry.route_message(_create_room_message(1, "private_room", ""))
	registry.route_message(_create_room_message(2, "public_room", "Alpha"))

	var public_room_id := String(registry.peer_room_bindings.get(2, ""))
	registry.route_message(_join_room_message(3, public_room_id))
	var snapshot = registry.build_directory_snapshot()

	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(registry.room_runtimes.size() == 2, "registry should track two room runtimes", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(1, "")) != "", "private host should be bound to its room", prefix) and ok
	ok = TestAssert.is_true(public_room_id != "", "public host should be bound to its room", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(3, "")) == public_room_id, "joined peer should bind to public room", prefix) and ok
	ok = TestAssert.is_true(snapshot.entries.size() == 1, "directory should only include public room entries", prefix) and ok
	ok = TestAssert.is_true(snapshot.entries[0].member_count == 2, "public room entry should update member_count after join", prefix) and ok
	ok = TestAssert.is_true(snapshot.entries[0].room_display_name == "Alpha", "public room entry should preserve display name", prefix) and ok

	registry.queue_free()
	return ok


func _test_registry_routes_idle_room_resume_request() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var directed_messages: Array[Dictionary] = []
	registry.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	registry.route_message(_create_room_message(2, "private_room", ""))
	var room_id := String(registry.peer_room_bindings.get(2, ""))
	registry.route_message(_join_room_message(3, room_id))
	var member_session := _find_latest_message_for_peer(directed_messages, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	registry.handle_peer_disconnected(3)
	registry.route_message(_resume_room_message(9, room_id, member_session, ""))

	var accepted := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.ROOM_JOIN_ACCEPTED)
	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(not accepted.is_empty(), "registry should route idle ROOM_RESUME_REQUEST to room runtime", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(9, "")) == room_id, "registry should bind resumed idle transport to room", prefix) and ok

	registry.queue_free()
	return ok


func _test_registry_repairs_stale_idle_resume_room_id() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var directed_messages: Array[Dictionary] = []
	registry.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	registry.route_message(_create_room_message(2, "private_room", ""))
	var room_id := String(registry.peer_room_bindings.get(2, ""))
	registry.route_message(_join_room_message(3, room_id))
	var member_session := _find_latest_message_for_peer(directed_messages, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	registry.handle_peer_disconnected(3)
	registry.route_message(_resume_room_message(9, "stale_room_from_cache", member_session, ""))

	var accepted := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.ROOM_JOIN_ACCEPTED)
	var rejected := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(not accepted.is_empty(), "registry should repair stale idle resume room_id by member token", prefix) and ok
	ok = TestAssert.is_true(rejected.is_empty(), "registry should not reject repaired idle resume request", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(9, "")) == room_id, "registry should bind repaired idle resume to actual room", prefix) and ok

	registry.queue_free()
	return ok


func _test_registry_rebinds_active_match_resume_transport() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var directed_messages: Array[Dictionary] = []
	var broadcasts: Array[Dictionary] = []
	registry.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	registry.broadcast_message.connect(func(message: Dictionary) -> void:
		broadcasts.append(message.duplicate(true))
	)

	registry.route_message(_create_room_message(2, "private_room", ""))
	var room_id := String(registry.peer_room_bindings.get(2, ""))
	registry.route_message(_join_room_message(3, room_id))
	var member_session := _find_latest_message_for_peer(directed_messages, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})
	var loading_snapshot := _latest_loading_snapshot(broadcasts)
	registry.route_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 2,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	registry.route_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 3,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	registry.handle_peer_disconnected(3)
	registry.route_message(_resume_room_message(9, room_id, member_session, String(loading_snapshot.get("match_id", ""))))

	var accepted := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.MATCH_RESUME_ACCEPTED)
	var runtime: ServerRoomRuntime = registry.room_runtimes.get(room_id, null)
	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(not accepted.is_empty(), "registry should route active match resume to room runtime", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(9, "")) == room_id, "registry should bind active resume transport to room", prefix) and ok
	ok = TestAssert.is_true(runtime != null and runtime.has_peer(9), "runtime should recognize resumed transport peer", prefix) and ok

	registry.queue_free()
	return ok


func _test_registry_repairs_stale_active_resume_room_id() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var directed_messages: Array[Dictionary] = []
	var broadcasts: Array[Dictionary] = []
	registry.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	registry.broadcast_message.connect(func(message: Dictionary) -> void:
		broadcasts.append(message.duplicate(true))
	)

	registry.route_message(_create_room_message(2, "private_room", ""))
	var room_id := String(registry.peer_room_bindings.get(2, ""))
	registry.route_message(_join_room_message(3, room_id))
	var member_session := _find_latest_message_for_peer(directed_messages, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})
	var loading_snapshot := _latest_loading_snapshot(broadcasts)
	registry.route_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 2,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	registry.route_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 3,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	registry.handle_peer_disconnected(3)
	registry.route_message(_resume_room_message(9, "stale_room_from_cache", member_session, String(loading_snapshot.get("match_id", ""))))

	var accepted := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.MATCH_RESUME_ACCEPTED)
	var rejected := _find_latest_message_for_peer(directed_messages, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var runtime: ServerRoomRuntime = registry.room_runtimes.get(room_id, null)
	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(not accepted.is_empty(), "registry should repair stale active resume room_id by member token", prefix) and ok
	ok = TestAssert.is_true(rejected.is_empty(), "registry should not reject repaired active resume request", prefix) and ok
	ok = TestAssert.is_true(String(registry.peer_room_bindings.get(9, "")) == room_id, "registry should bind repaired active resume to actual room", prefix) and ok
	ok = TestAssert.is_true(runtime != null and runtime.has_peer(9), "runtime should recognize repaired active resume peer", prefix) and ok

	registry.queue_free()
	return ok


func _test_directory_subscriber_receives_public_room_after_create() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var directed_messages: Array[Dictionary] = []
	registry.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed_messages.append({
			"peer_id": peer_id,
			"message": message.duplicate(true),
		})
	)

	registry.route_message({
		"message_type": TransportMessageTypesScript.ROOM_DIRECTORY_SUBSCRIBE,
		"sender_peer_id": 88,
	})
	registry.route_message(_create_room_message(7, "public_room", "Lobby Alpha"))

	var latest_snapshot := _find_latest_directory_snapshot_for_peer(directed_messages, 88)
	var prefix := "server_room_registry_test"
	var ok := true
	ok = TestAssert.is_true(latest_snapshot.size() > 0, "directory subscriber should receive snapshot payload", prefix) and ok
	ok = TestAssert.is_true(latest_snapshot.get("entries", []).size() == 1, "directory subscriber should receive created public room", prefix) and ok
	ok = TestAssert.is_true(
		String(latest_snapshot.get("entries", [{}])[0].get("room_display_name", "")) == "Lobby Alpha",
		"directory subscriber should receive public room display name",
		prefix
	) and ok

	registry.queue_free()
	return ok


func _create_room_message(peer_id: int, room_kind: String, room_display_name: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}


func _join_room_message(peer_id: int, room_id: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}


func _resume_room_message(peer_id: int, room_id: String, member_session: Dictionary, match_id: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": peer_id,
		"room_id": room_id,
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": match_id,
	}


func _latest_loading_snapshot(messages: Array[Dictionary]) -> Dictionary:
	for index in range(messages.size() - 1, -1, -1):
		var message := messages[index]
		if String(message.get("message_type", "")) == TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
			return Dictionary(message.get("snapshot", {}))
	return {}


func _find_latest_message_for_peer(messages: Array[Dictionary], peer_id: int, message_type: String) -> Dictionary:
	for index in range(messages.size() - 1, -1, -1):
		var payload: Dictionary = messages[index]
		if int(payload.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = payload.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}


func _find_latest_directory_snapshot_for_peer(messages: Array[Dictionary], peer_id: int) -> Dictionary:
	for index in range(messages.size() - 1, -1, -1):
		var payload: Dictionary = messages[index]
		if int(payload.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = payload.get("message", {})
		if String(message.get("message_type", "")) == TransportMessageTypesScript.ROOM_DIRECTORY_SNAPSHOT:
			return message.get("snapshot", {})
	return {}
