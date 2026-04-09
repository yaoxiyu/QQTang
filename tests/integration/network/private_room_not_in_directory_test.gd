extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := _test_private_room_is_excluded_from_directory_snapshot()
	if ok:
		print("private_room_not_in_directory_test: PASS")


func _test_private_room_is_excluded_from_directory_snapshot() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)

	registry.route_message(_create_room_message(11, "private_room", ""))
	registry.route_message(_create_room_message(12, "public_room", "Visible Room"))

	var snapshot = registry.build_directory_snapshot()
	var prefix := "private_room_not_in_directory_test"
	var ok := true
	ok = TestAssert.is_true(snapshot.entries.size() == 1, "directory should only contain one public entry", prefix) and ok
	ok = TestAssert.is_true(snapshot.entries[0].room_kind == "public_room", "directory should exclude private room kind", prefix) and ok
	ok = TestAssert.is_true(snapshot.entries[0].room_display_name == "Visible Room", "directory should keep public room display name", prefix) and ok

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
