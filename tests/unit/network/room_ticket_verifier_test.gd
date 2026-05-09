extends "res://tests/gut/base/qqt_unit_test.gd"

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const RoomTicketVerifierScript = preload("res://network/session/auth/room_ticket_verifier.gd")

const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func test_main() -> void:
	var ok := true
	ok = _test_verify_create_ticket_success() and ok
	ok = _test_verify_rejects_invalid_signature() and ok
	ok = _test_verify_rejects_target_mismatch() and ok
	ok = _test_loadout_allowed_guard() and ok


func _test_verify_create_ticket_success() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	verifier.configure(ROOM_TICKET_SECRET)
	var message := _build_message(2, "create", "", "private_room", "")
	var result = verifier.verify_create_ticket(message)

	var prefix := "room_ticket_verifier_test"
	var ok := true
	ok = qqt_check(bool(result.ok), "valid create ticket should pass", prefix) and ok
	ok = qqt_check(result.claim != null, "valid create ticket should return claim", prefix) and ok
	if result.claim != null:
		ok = qqt_check(String(result.claim.account_id) == "account_2", "claim should preserve account id", prefix) and ok
	return ok


func _test_verify_rejects_invalid_signature() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	verifier.configure(ROOM_TICKET_SECRET)
	var message := _build_message(2, "create", "", "private_room", "")
	message["room_ticket"] = String(message.get("room_ticket", "")) + "_tampered"
	var result = verifier.verify_create_ticket(message)
	return qqt_check(not bool(result.ok) and String(result.error_code) == "ROOM_TICKET_SIGNATURE_INVALID", "invalid signature should be rejected", "room_ticket_verifier_test")


func _test_verify_rejects_target_mismatch() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	verifier.configure(ROOM_TICKET_SECRET)
	var message := _build_message(2, "join", "room_good", "", "")
	message["room_id_hint"] = "room_bad"
	var result = verifier.verify_join_ticket(message)
	return qqt_check(not bool(result.ok) and String(result.error_code) == "ROOM_TICKET_TARGET_INVALID", "mismatched room target should be rejected", "room_ticket_verifier_test")


func _test_loadout_allowed_guard() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	verifier.configure(ROOM_TICKET_SECRET)
	var message := _build_message(2, "create", "", "private_room", "")
	var result = verifier.verify_create_ticket(message)
	if not bool(result.ok) or result.claim == null:
		return qqt_check(false, "setup create ticket should verify", "room_ticket_verifier_test")
	return qqt_check(
		not verifier.is_loadout_allowed(result.claim, "character_not_owned", BubbleCatalogScript.get_default_bubble_id()),
		"unowned loadout should fail verifier guard",
		"room_ticket_verifier_test"
	)


func _build_message(peer_id: int, purpose: String, room_id: String, room_kind: String, match_id: String) -> Dictionary:
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": match_id,
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_%s_%d" % [purpose, peer_id],
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	return {
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"room_kind": room_kind,
		"match_id": match_id,
		"room_ticket": "%s.%s" % [encoded_payload, _to_base64_url(digest)],
		"room_ticket_id": String(payload.get("ticket_id", "")),
	}


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")

