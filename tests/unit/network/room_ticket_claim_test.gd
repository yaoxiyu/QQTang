extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")


func test_main() -> void:
	var source := {
		"ticket_id": "ticket_alpha",
		"account_id": "account_alpha",
		"profile_id": "profile_alpha",
		"device_session_id": "dsess_alpha",
		"purpose": "resume",
		"room_id": "room_alpha",
		"room_kind": "private_room",
		"requested_match_id": "match_alpha",
		"display_name": "Alpha",
		"allowed_character_ids": ["character_default"],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": ["bubble_style_default"],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": 1,
		"expire_at_unix_sec": 2,
		"nonce": "nonce_alpha",
		"signature": "sig_alpha",
	}
	var claim = RoomTicketClaimScript.from_dict(source)
	var restored = RoomTicketClaimScript.from_dict(claim.to_dict())

	var prefix := "room_ticket_claim_test"
	var ok := true
	ok = qqt_check(String(restored.ticket_id) == "ticket_alpha", "from_dict should restore ticket id", prefix) and ok
	ok = qqt_check(String(restored.account_id) == "account_alpha", "from_dict should restore account id", prefix) and ok
	ok = qqt_check(String(restored.requested_match_id) == "match_alpha", "from_dict should restore requested match id", prefix) and ok
	ok = qqt_check(restored.allowed_character_ids == ["character_default"], "from_dict should restore allowed characters", prefix) and ok
	ok = qqt_check(String(restored.signature) == "sig_alpha", "to_dict/from_dict should preserve signature", prefix) and ok


