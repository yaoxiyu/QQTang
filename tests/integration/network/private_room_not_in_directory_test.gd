extends "res://tests/gut/base/qqt_integration_test.gd"

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func test_main() -> void:
	var ok := _test_private_room_is_excluded_from_directory_snapshot()


func _test_private_room_is_excluded_from_directory_snapshot() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)

	registry.route_message(_create_room_message(11, "private_room", ""))
	registry.route_message(_create_room_message(12, "public_room", "Visible Room"))

	var snapshot = registry.build_directory_snapshot()
	var prefix := "private_room_not_in_directory_test"
	var ok := true
	ok = qqt_check(snapshot.entries.size() == 1, "directory should only contain one public entry", prefix) and ok
	ok = qqt_check(snapshot.entries[0].room_kind == "public_room", "directory should exclude private room kind", prefix) and ok
	ok = qqt_check(snapshot.entries[0].room_display_name == "Visible Room", "directory should keep public room display name", prefix) and ok

	registry.queue_free()
	return ok


func _create_room_message(peer_id: int, room_kind: String, room_display_name: String) -> Dictionary:
	var ticket := _make_room_ticket({
		"ticket_id": "ticket_create_%d" % peer_id,
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": "create",
		"room_id": "",
		"room_kind": room_kind,
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_create_%d" % peer_id,
	})
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _make_room_ticket(payload: Dictionary) -> Dictionary:
	var json := JSON.stringify(payload)
	var encoded_payload := Marshalls.raw_to_base64(json.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	var signature := Marshalls.raw_to_base64(digest).replace("+", "-").replace("/", "_").trim_suffix("=")
	var token := "%s.%s" % [encoded_payload, signature]
	var result := payload.duplicate(true)
	result["token"] = token
	return result

