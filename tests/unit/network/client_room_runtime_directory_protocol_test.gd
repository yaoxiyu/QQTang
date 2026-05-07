extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


var _received_directory_snapshot = null
var _received_room_snapshot: RoomSnapshot = null


class FakeDirectoryTransport extends ENetBattleTransport:
	var sent_messages: Array[Dictionary] = []

	func is_transport_connected() -> bool:
		return true

	func send_to_peer(peer_id: int, message: Dictionary) -> void:
		sent_messages.append({
			"peer_id": peer_id,
			"message": message.duplicate(true),
		})


func test_main() -> void:
	call_deferred("_main_body")


func _main_body() -> void:
	var ok := true
	ok = _test_directory_requests_are_forwarded_to_transport() and ok
	ok = _test_directory_snapshot_message_is_parsed_and_emitted() and ok
	ok = _test_assignment_ready_message_updates_authoritative_snapshot() and ok


func _test_directory_requests_are_forwarded_to_transport() -> bool:
	var runtime := ClientRoomRuntimeScript.new()
	add_child(runtime)
	runtime.set_process(false)
	var transport := FakeDirectoryTransport.new()
	runtime.add_child(transport)
	runtime.inject_test_room_transport(transport)
	runtime._connected = true

	runtime.request_room_directory_snapshot()
	runtime.subscribe_room_directory()
	runtime.unsubscribe_room_directory()

	var prefix := "client_room_runtime_directory_protocol_test"
	var ok := true
	ok = qqt_check(transport.sent_messages.size() == 3, "directory protocol should send three messages", prefix) and ok
	ok = qqt_check(
		String(transport.sent_messages[0].get("message", {}).get("message_type", "")) == TransportMessageTypesScript.ROOM_DIRECTORY_REQUEST,
		"request should send ROOM_DIRECTORY_REQUEST",
		prefix
	) and ok
	ok = qqt_check(
		String(transport.sent_messages[1].get("message", {}).get("message_type", "")) == TransportMessageTypesScript.ROOM_DIRECTORY_SUBSCRIBE,
		"subscribe should send ROOM_DIRECTORY_SUBSCRIBE",
		prefix
	) and ok
	ok = qqt_check(
		String(transport.sent_messages[2].get("message", {}).get("message_type", "")) == TransportMessageTypesScript.ROOM_DIRECTORY_UNSUBSCRIBE,
		"unsubscribe should send ROOM_DIRECTORY_UNSUBSCRIBE",
		prefix
	) and ok
	ok = qqt_check(runtime._directory_subscribed == false, "unsubscribe should clear subscribed flag", prefix) and ok

	runtime.queue_free()
	return ok


func _test_assignment_ready_message_updates_authoritative_snapshot() -> bool:
	var runtime := ClientRoomRuntimeScript.new()
	add_child(runtime)
	runtime.set_process(false)
	_received_room_snapshot = null
	runtime.room_snapshot_received.connect(func(snapshot: RoomSnapshot) -> void:
		_received_room_snapshot = snapshot
	)

	runtime._route_message({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": {
			"room_id": "ROOM-ASSIGN",
			"room_kind": "public_room",
			"topology": "dedicated_server",
			"snapshot_revision": 12,
			"selected_map_id": "map_classic_square",
			"rule_set_id": "ruleset_classic",
			"mode_id": "box",
			"members": [{
				"peer_id": 7,
				"player_name": "local",
				"is_local_player": true,
			}],
		},
	})
	runtime._route_message({
		"message_type": TransportMessageTypesScript.ROOM_MATCH_ASSIGNMENT_READY,
		"assignment_id": "assignment-1",
		"battle_id": "battle-1",
		"match_id": "match-1",
		"battle_server_host": "qqt-ds-slot-001",
		"battle_server_port": 9000,
		"battle_entry_ready": true,
		"battle_phase": "ready",
		"battle_terminal_reason": "manual_start",
		"battle_status_text": "Battle ready",
	})
	runtime._route_message({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": {
			"room_id": "ROOM-ASSIGN",
			"room_kind": "public_room",
			"topology": "dedicated_server",
			"snapshot_revision": 13,
			"members": [{
				"peer_id": 7,
				"player_name": "local",
				"is_local_player": true,
			}],
		},
	})

	var prefix := "client_room_runtime_directory_protocol_test"
	var ok := true
	ok = qqt_check(_received_room_snapshot != null, "assignment ready should emit an updated room snapshot", prefix) and ok
	if _received_room_snapshot != null:
		ok = qqt_check(String(_received_room_snapshot.room_id) == "ROOM-ASSIGN", "assignment ready should preserve room id", prefix) and ok
		ok = qqt_check(String(_received_room_snapshot.room_phase) == "battle_entry_ready", "assignment ready should promote room phase", prefix) and ok
		ok = qqt_check(String(_received_room_snapshot.current_assignment_id) == "assignment-1", "assignment id should map into snapshot", prefix) and ok
		ok = qqt_check(String(_received_room_snapshot.current_battle_id) == "battle-1", "battle id should map into snapshot", prefix) and ok
		ok = qqt_check(String(_received_room_snapshot.current_match_id) == "match-1", "match id should map into snapshot", prefix) and ok
		ok = qqt_check(String(_received_room_snapshot.battle_server_host) == "qqt-ds-slot-001", "DS host should map into snapshot", prefix) and ok
		ok = qqt_check(int(_received_room_snapshot.battle_server_port) == 9000, "DS port should map into snapshot", prefix) and ok
		ok = qqt_check(_received_room_snapshot.members.size() == 1, "assignment ready should preserve members from last snapshot", prefix) and ok

	runtime.queue_free()
	return ok


func _test_directory_snapshot_message_is_parsed_and_emitted() -> bool:
	var runtime := ClientRoomRuntimeScript.new()
	add_child(runtime)
	runtime.set_process(false)
	_received_directory_snapshot = null
	runtime.room_directory_snapshot_received.connect(func(snapshot) -> void:
		_received_directory_snapshot = snapshot
	)

	runtime._route_message({
		"message_type": TransportMessageTypesScript.ROOM_DIRECTORY_SNAPSHOT,
		"snapshot": {
			"revision": 5,
			"server_host": "127.0.0.1",
			"server_port": 9100,
			"entries": [{
				"room_id": "ROOM-DIR",
				"room_display_name": "Directory Room",
				"room_kind": "public_room",
				"owner_peer_id": 8,
				"owner_name": "Owner",
				"selected_map_id": "map_a",
				"rule_set_id": "rule_a",
				"mode_id": "mode_a",
				"member_count": 2,
				"max_players": 4,
				"match_active": false,
				"joinable": true,
			}],
		},
	})

	var prefix := "client_room_runtime_directory_protocol_test"
	var ok := true
	ok = qqt_check(_received_directory_snapshot != null, "snapshot signal should emit parsed snapshot", prefix) and ok
	if _received_directory_snapshot != null:
		ok = qqt_check(int(_received_directory_snapshot.revision) == 5, "parsed snapshot should preserve revision", prefix) and ok
		ok = qqt_check(_received_directory_snapshot.entries.size() == 1, "parsed snapshot should preserve entries", prefix) and ok
		ok = qqt_check(String(_received_directory_snapshot.entries[0].room_display_name) == "Directory Room", "parsed snapshot should preserve display name", prefix) and ok

	runtime.queue_free()
	return ok
