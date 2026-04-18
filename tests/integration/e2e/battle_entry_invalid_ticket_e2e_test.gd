extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")

const BATTLE_TICKET_SECRET := "dev_battle_ticket_secret"


func test_main() -> void:
	var verifier := BattleTicketVerifierScript.new()
	verifier.configure(BATTLE_TICKET_SECRET)
	var now := int(Time.get_unix_time_from_system())
	var manifest := _build_manifest()
	var ok := true
	var prefix := "battle_entry_invalid_ticket_e2e_test"

	var bad_signature := _build_message("battle_001", "account_1", "profile_1", now + 60, "bad_signature")
	var r1 := verifier.verify_entry_ticket(bad_signature, "battle_001", manifest)
	ok = qqt_check(String(r1.get("error_code", "")) == "BATTLE_TICKET_SIGNATURE_INVALID", "signature mismatch should be rejected", prefix) and ok

	var expired := _build_message("battle_001", "account_1", "profile_1", now - 1)
	var r2 := verifier.verify_entry_ticket(expired, "battle_001", manifest)
	ok = qqt_check(String(r2.get("error_code", "")) == "BATTLE_TICKET_EXPIRED", "expired ticket should be rejected", prefix) and ok

	var battle_mismatch := _build_message("battle_999", "account_1", "profile_1", now + 60)
	var r3 := verifier.verify_entry_ticket(battle_mismatch, "battle_001", manifest)
	ok = qqt_check(String(r3.get("error_code", "")) == "BATTLE_ID_MISMATCH", "battle id mismatch should be rejected", prefix) and ok

	var member_mismatch := _build_message("battle_001", "account_unknown", "profile_unknown", now + 60)
	var r4 := verifier.verify_entry_ticket(member_mismatch, "battle_001", manifest)
	ok = qqt_check(String(r4.get("error_code", "")) == "BATTLE_MEMBER_MISMATCH", "member mismatch should be rejected", prefix) and ok

	var lock_mismatch := _build_message("battle_001", "account_1", "profile_1", now + 60, "", "map_other", "rule_001", "mode_001")
	var r5 := verifier.verify_entry_ticket(lock_mismatch, "battle_001", manifest)
	ok = qqt_check(String(r5.get("error_code", "")) == "BATTLE_LOCK_MISMATCH", "map-rule-mode lock mismatch should be rejected", prefix) and ok



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


func _build_message(
	battle_id: String,
	account_id: String,
	profile_id: String,
	expire_at_unix_sec: int,
	signature_override: String = "",
	locked_map_id: String = "map_001",
	locked_rule_set_id: String = "rule_001",
	locked_mode_id: String = "mode_001"
) -> Dictionary:
	var payload := {
		"ticket_id": "bticket_001",
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": "dsess_001",
		"purpose": "battle_entry",
		"requested_match_id": "match_001",
		"assignment_id": "assign_001",
		"locked_map_id": locked_map_id,
		"locked_rule_set_id": locked_rule_set_id,
		"locked_mode_id": locked_mode_id,
		"assigned_team_id": 1,
		"expected_member_count": 2,
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": expire_at_unix_sec,
		"nonce": "nonce_001",
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var signature := signature_override
	if signature.is_empty():
		var crypto := Crypto.new()
		signature = _to_base64_url(crypto.hmac_digest(HashingContext.HASH_SHA256, BATTLE_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer()))
	return {
		"battle_id": battle_id,
		"battle_ticket": "%s.%s" % [encoded_payload, signature],
		"battle_ticket_id": "bticket_001",
	}


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")

