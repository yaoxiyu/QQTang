extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := _test_two_rooms_keep_independent_runtime_and_match_state()
	if ok:
		print("dedicated_server_multi_room_test: PASS")


func _test_two_rooms_keep_independent_runtime_and_match_state() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)

	var mode_id := ModeCatalogScript.get_default_mode_id()
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var rule_id := String(mode_metadata.get("rule_set_id", RuleSetCatalogScript.get_default_rule_id()))
	var map_id := String(mode_metadata.get("default_map_id", MapCatalogScript.get_default_map_id()))

	registry.route_message(_create_room_message(2, "public_room", "Alpha", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(3, String(registry.peer_room_bindings.get(2, ""))))
	registry.route_message(_create_room_message(4, "private_room", "", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(5, String(registry.peer_room_bindings.get(4, ""))))

	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	registry.route_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})

	var public_room_id := String(registry.peer_room_bindings.get(2, ""))
	var private_room_id := String(registry.peer_room_bindings.get(4, ""))
	var public_runtime = registry.room_runtimes.get(public_room_id, null)
	var private_runtime = registry.room_runtimes.get(private_room_id, null)
	var directory_snapshot = registry.build_directory_snapshot()

	var prefix := "dedicated_server_multi_room_test"
	var ok := true
	ok = TestAssert.is_true(registry.room_runtimes.size() == 2, "registry should keep both room runtimes alive", prefix) and ok
	ok = TestAssert.is_true(
		public_runtime != null and public_runtime._room_service != null and bool(public_runtime._room_service.room_state.match_active),
		"public room should enter active room match state independently",
		prefix
	) and ok
	ok = TestAssert.is_true(
		private_runtime != null and private_runtime._room_service != null and not bool(private_runtime._room_service.room_state.match_active),
		"private room should stay idle while public room starts",
		prefix
	) and ok
	ok = TestAssert.is_true(directory_snapshot.entries.size() == 1, "directory should still expose only the public room", prefix) and ok
	ok = TestAssert.is_true(bool(directory_snapshot.entries[0].match_active), "directory should mark active public match", prefix) and ok
	ok = TestAssert.is_true(not bool(directory_snapshot.entries[0].joinable), "active public room should not stay joinable", prefix) and ok

	registry.queue_free()
	return ok


func _create_room_message(peer_id: int, room_kind: String, room_display_name: String, map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"map_id": map_id,
		"rule_set_id": rule_id,
		"mode_id": mode_id,
	}


func _join_room_message(peer_id: int, room_id: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}
