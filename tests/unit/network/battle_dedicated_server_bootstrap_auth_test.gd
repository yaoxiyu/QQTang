extends Node

const BootstrapScript = preload("res://network/runtime/battle_dedicated_server_bootstrap.gd")
const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

const BATTLE_TICKET_SECRET := "dev_battle_ticket_secret"
var _bootstrap_nodes: Array = []


func _ready() -> void:
	var ok := true
	ok = _test_entry_validate_success() and ok
	ok = _test_entry_validate_rejects_member_mismatch() and ok
	ok = _test_resume_validate_missing_token() and ok
	ok = _test_resume_validate_battle_mismatch() and ok
	ok = _test_resume_validate_member_mismatch() and ok
	ok = _test_resume_validate_window_expired() and ok
	ok = _test_resume_validate_success() and ok
	_cleanup_bootstraps()
	if ok:
		print("battle_dedicated_server_bootstrap_auth_test: PASS")


func _test_entry_validate_success() -> bool:
	var bootstrap = _create_bootstrap()
	var message := _build_ticket_message("battle_001", "account_1", "profile_1", int(Time.get_unix_time_from_system()) + 60)
	var result: Dictionary = bootstrap._validate_battle_entry_request(message)
	return TestAssert.is_true(bool(result.get("ok", false)), "battle entry validation should pass for valid member", "battle_ds_bootstrap_auth_test")


func _test_entry_validate_rejects_member_mismatch() -> bool:
	var bootstrap = _create_bootstrap()
	var message := _build_ticket_message("battle_001", "account_9", "profile_9", int(Time.get_unix_time_from_system()) + 60)
	var result: Dictionary = bootstrap._validate_battle_entry_request(message)
	return TestAssert.is_true(String(result.get("error_code", "")) == "BATTLE_MEMBER_MISMATCH", "unknown member should be rejected", "battle_ds_bootstrap_auth_test")


func _test_resume_validate_missing_token() -> bool:
	var bootstrap = _create_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = _build_session("account_1", "profile_1", "token_abc", Time.get_ticks_msec() + 10000)
	var result: Dictionary = bootstrap._validate_battle_resume_request({"battle_id": "battle_001", "member_id": "account_1:profile_1"})
	return TestAssert.is_true(String(result.get("error_code", "")) == "BATTLE_RESUME_TOKEN_MISSING", "missing resume token should reject", "battle_ds_bootstrap_auth_test")


func _test_resume_validate_battle_mismatch() -> bool:
	var bootstrap = _create_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = _build_session("account_1", "profile_1", "token_abc", Time.get_ticks_msec() + 10000)
	var result: Dictionary = bootstrap._validate_battle_resume_request({
		"battle_id": "battle_999",
		"member_id": "account_1:profile_1",
		"resume_token": "token_abc",
	})
	return TestAssert.is_true(String(result.get("error_code", "")) == "BATTLE_ID_MISMATCH", "battle mismatch should reject", "battle_ds_bootstrap_auth_test")


func _test_resume_validate_member_mismatch() -> bool:
	var bootstrap = _create_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = _build_session("account_1", "profile_1", "token_abc", Time.get_ticks_msec() + 10000)
	var result: Dictionary = bootstrap._validate_battle_resume_request({
		"battle_id": "battle_001",
		"member_id": "account_1:profile_1",
		"resume_token": "token_abc",
		"account_id": "account_2",
	})
	return TestAssert.is_true(String(result.get("error_code", "")) == "BATTLE_RESUME_ACCOUNT_MISMATCH", "account mismatch should reject", "battle_ds_bootstrap_auth_test")


func _test_resume_validate_window_expired() -> bool:
	var bootstrap = _create_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = _build_session("account_1", "profile_1", "token_abc", Time.get_ticks_msec() - 1)
	var result: Dictionary = bootstrap._validate_battle_resume_request({
		"battle_id": "battle_001",
		"member_id": "account_1:profile_1",
		"resume_token": "token_abc",
	})
	return TestAssert.is_true(String(result.get("error_code", "")) == "BATTLE_RESUME_WINDOW_EXPIRED", "expired resume window should reject", "battle_ds_bootstrap_auth_test")


func _test_resume_validate_success() -> bool:
	var bootstrap = _create_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = _build_session("account_1", "profile_1", "token_abc", Time.get_ticks_msec() + 10000)
	var result: Dictionary = bootstrap._validate_battle_resume_request({
		"battle_id": "battle_001",
		"member_id": "account_1:profile_1",
		"resume_token": "token_abc",
		"profile_id": "profile_1",
	})
	return TestAssert.is_true(bool(result.get("ok", false)), "valid resume request should pass", "battle_ds_bootstrap_auth_test")


func _create_bootstrap():
	var bootstrap = BootstrapScript.new()
	bootstrap._battle_id = "battle_001"
	bootstrap._manifest = {
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
	bootstrap._battle_ticket_verifier = BattleTicketVerifierScript.new()
	bootstrap._battle_ticket_verifier.configure(BATTLE_TICKET_SECRET)
	_bootstrap_nodes.append(bootstrap)
	return bootstrap


func _build_session(account_id: String, profile_id: String, token: String, deadline_msec: int) -> Dictionary:
	return {
		"member_id": "%s:%s" % [account_id, profile_id],
		"account_id": account_id,
		"profile_id": profile_id,
		"resume_token_hash": ResumeTokenUtilsScript.hash_resume_token(token),
		"disconnect_deadline_msec": deadline_msec,
	}


func _build_ticket_message(battle_id: String, account_id: String, profile_id: String, expire_at_unix_sec: int) -> Dictionary:
	var payload := {
		"ticket_id": "bticket_001",
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": "dsess_001",
		"purpose": "battle_entry",
		"requested_match_id": "match_001",
		"assignment_id": "assign_001",
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


func _cleanup_bootstraps() -> void:
	for bootstrap in _bootstrap_nodes:
		if bootstrap != null and is_instance_valid(bootstrap):
			bootstrap.free()
	_bootstrap_nodes.clear()
