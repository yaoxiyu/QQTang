extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")

const BATTLE_TICKET_SECRET := "dev_battle_ticket_secret"


func test_main() -> void:
	var ok := true
	ok = _test_verify_success() and ok
	ok = _test_verify_rejects_missing_token() and ok
	ok = _test_verify_rejects_battle_mismatch() and ok
	ok = _test_verify_rejects_expired_token() and ok


func _test_verify_success() -> bool:
	var verifier = BattleTicketVerifierScript.new()
	verifier.configure(BATTLE_TICKET_SECRET)
	var message := _build_message("assign_001", "battle_001", "account_1", "profile_1", int(Time.get_unix_time_from_system()) + 60)
	var result := verifier.verify_entry_ticket(message, "battle_001", _build_manifest())
	return qqt_check(bool(result.get("ok", false)), "valid battle ticket should pass", "battle_ticket_verifier_test")


func _test_verify_rejects_missing_token() -> bool:
	var verifier = BattleTicketVerifierScript.new()
	verifier.configure(BATTLE_TICKET_SECRET)
	var result := verifier.verify_entry_ticket({}, "battle_001", _build_manifest())
	return qqt_check(String(result.get("error_code", "")) == "BATTLE_TICKET_MISSING", "missing battle ticket should reject", "battle_ticket_verifier_test")


func _test_verify_rejects_battle_mismatch() -> bool:
	var verifier = BattleTicketVerifierScript.new()
	verifier.configure(BATTLE_TICKET_SECRET)
	var message := _build_message("assign_001", "battle_002", "account_1", "profile_1", int(Time.get_unix_time_from_system()) + 60)
	var result := verifier.verify_entry_ticket(message, "battle_001", _build_manifest())
	return qqt_check(String(result.get("error_code", "")) == "BATTLE_ID_MISMATCH", "battle id mismatch should reject", "battle_ticket_verifier_test")


func _test_verify_rejects_expired_token() -> bool:
	var verifier = BattleTicketVerifierScript.new()
	verifier.configure(BATTLE_TICKET_SECRET)
	var message := _build_message("assign_001", "battle_001", "account_1", "profile_1", int(Time.get_unix_time_from_system()) - 1)
	var result := verifier.verify_entry_ticket(message, "battle_001", _build_manifest())
	return qqt_check(String(result.get("error_code", "")) == "BATTLE_TICKET_EXPIRED", "expired battle ticket should reject", "battle_ticket_verifier_test")


func _build_manifest() -> Dictionary:
	return {
		"assignment_id": "assign_001",
		"battle_id": "battle_001",
		"match_id": "match_001",
		"map_id": "map_001",
		"rule_set_id": "rule_001",
		"mode_id": "mode_001",
		"expected_member_count": 2,
		"members": [
			{"account_id": "account_1", "profile_id": "profile_1", "assigned_team_id": 1},
			{"account_id": "account_2", "profile_id": "profile_2", "assigned_team_id": 2},
		],
	}


func _build_message(assignment_id: String, battle_id: String, account_id: String, profile_id: String, expire_at_unix_sec: int) -> Dictionary:
	var payload := {
		"ticket_id": "bticket_001",
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": "dsess_001",
		"purpose": "battle_entry",
		"requested_match_id": "match_001",
		"assignment_id": assignment_id,
		"locked_map_id": "map_001",
		"locked_rule_set_id": "rule_001",
		"locked_mode_id": "mode_001",
		"assigned_team_id": 1,
		"expected_member_count": 2,
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": expire_at_unix_sec,
		"nonce": "nonce_001",
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var crypto := Crypto.new()
	var signature := _to_base64_url(crypto.hmac_digest(HashingContext.HASH_SHA256, BATTLE_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer()))
	return {
		"battle_id": battle_id,
		"battle_ticket": "%s.%s" % [encoded_payload, signature],
		"battle_ticket_id": "bticket_001",
	}


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")

