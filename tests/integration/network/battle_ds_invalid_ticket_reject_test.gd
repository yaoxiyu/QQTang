extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

const BATTLE_TICKET_SECRET := "dev_battle_ticket_secret"



class BattleBootstrapProbe:
	extends "res://network/runtime/battle_dedicated_server_bootstrap.gd"
	var sent_messages: Array[Dictionary] = []

	func send_to_peer(peer_id: int, message: Dictionary) -> void:
		sent_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})

	func _send_to_peer(peer_id: int, message: Dictionary) -> void:
		send_to_peer(peer_id, message)

	func latest_for_peer(peer_id: int, message_type: String) -> Dictionary:
		for index in range(sent_messages.size() - 1, -1, -1):
			var entry: Dictionary = sent_messages[index]
			if int(entry.get("peer_id", 0)) != peer_id:
				continue
			var message: Dictionary = entry.get("message", {})
			if String(message.get("message_type", "")) == message_type:
				return message
		return {}


func test_main() -> void:
	var ok := true
	ok = _test_invalid_battle_entry_ticket_is_rejected() and ok
	ok = _test_invalid_resume_token_is_rejected() and ok


func _test_invalid_battle_entry_ticket_is_rejected() -> bool:
	var bootstrap: BattleBootstrapProbe = _new_bootstrap()

	bootstrap._handle_battle_entry_request({
		"message_type": TransportMessageTypesScript.BATTLE_ENTRY_REQUEST,
		"sender_peer_id": 11,
		"battle_id": "battle_001",
		"battle_ticket": "broken_ticket",
		"battle_ticket_id": "ticket_invalid",
	})

	var rejected: Dictionary = bootstrap.latest_for_peer(11, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED)
	var prefix := "battle_ds_invalid_ticket_reject_test"
	var ok := true
	ok = qqt_check(not rejected.is_empty(), "invalid battle entry ticket should be rejected", prefix) and ok
	if not rejected.is_empty():
		ok = qqt_check(String(rejected.get("error", "")) == "BATTLE_TICKET_INVALID", "invalid battle entry should return BATTLE_TICKET_INVALID", prefix) and ok
	bootstrap.queue_free()
	return ok


func _test_invalid_resume_token_is_rejected() -> bool:
	var bootstrap: BattleBootstrapProbe = _new_bootstrap()
	bootstrap._member_sessions_by_id["account_1:profile_1"] = {
		"member_id": "account_1:profile_1",
		"account_id": "account_1",
		"profile_id": "profile_1",
		"resume_token_hash": ResumeTokenUtilsScript.hash_resume_token("token_good"),
		"disconnect_deadline_msec": Time.get_ticks_msec() + 5000,
		"match_peer_id": 1,
		"transport_peer_id": 0,
		"connection_state": "disconnected",
	}

	bootstrap._handle_battle_resume_request({
		"message_type": TransportMessageTypesScript.BATTLE_RESUME_REQUEST,
		"sender_peer_id": 19,
		"battle_id": "battle_001",
		"member_id": "account_1:profile_1",
		"resume_token": "token_bad",
	})

	var rejected: Dictionary = bootstrap.latest_for_peer(19, TransportMessageTypesScript.MATCH_RESUME_REJECTED)
	var prefix := "battle_ds_invalid_ticket_reject_test"
	var ok := true
	ok = qqt_check(not rejected.is_empty(), "invalid resume token should be rejected", prefix) and ok
	if not rejected.is_empty():
		ok = qqt_check(String(rejected.get("error", "")) == "BATTLE_RESUME_TOKEN_INVALID", "invalid resume should return BATTLE_RESUME_TOKEN_INVALID", prefix) and ok
	bootstrap.queue_free()
	return ok


func _new_bootstrap() -> BattleBootstrapProbe:
	var bootstrap := BattleBootstrapProbe.new()
	bootstrap._battle_id = "battle_001"
	bootstrap._assignment_id = "assign_001"
	bootstrap._match_id = "match_001"
	bootstrap._manifest = {
		"assignment_id": "assign_001",
		"battle_id": "battle_001",
		"match_id": "match_001",
		"map_id": "map_001",
		"rule_set_id": "rule_001",
		"mode_id": "mode_001",
		"expected_member_count": 1,
		"members": [
			{"account_id": "account_1", "profile_id": "profile_1", "assigned_team_id": 1},
		],
	}
	bootstrap._battle_ticket_verifier = BattleTicketVerifierScript.new()
	bootstrap._battle_ticket_verifier.configure(BATTLE_TICKET_SECRET)
	return bootstrap

