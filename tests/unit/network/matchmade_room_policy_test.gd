extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")
const RoomTicketVerifierScript = preload("res://network/session/auth/room_ticket_verifier.gd")


func test_main() -> void:
	var ok := true
	ok = _test_match_selection_is_locked() and ok
	ok = _test_casual_match_room_requires_expected_member_count() and ok
	ok = _test_match_ticket_claim_requires_assignment_locks() and ok


func _test_match_selection_is_locked() -> bool:
	var state = RoomServerStateScript.new()
	state.ensure_room("room_match", 1, "casual_match_room", "Ranked Room")
	var locked_map: String = String(state.selected_map_id)
	var locked_rule: String = String(state.selected_rule_id)
	var locked_mode: String = String(state.selected_mode_id)
	state.locked_map_id = locked_map
	state.locked_rule_set_id = locked_rule
	state.locked_mode_id = locked_mode

	state.set_selection("fake_map", "fake_rule", "fake_mode")

	var prefix := "casual_match_room_policy_test.selection"
	var ok := true
	ok = qqt_check(state.selected_map_id == locked_map, "match room should keep locked map", prefix) and ok
	ok = qqt_check(state.selected_rule_id == locked_rule, "match room should keep locked rule", prefix) and ok
	ok = qqt_check(state.selected_mode_id == locked_mode, "match room should keep locked mode", prefix) and ok
	return ok


func _test_casual_match_room_requires_expected_member_count() -> bool:
	var state = RoomServerStateScript.new()
	state.ensure_room("room_match", 1, "casual_match_room", "Ranked Room")
	state.expected_member_count = 2
	state.upsert_member(1, "Alpha", "", "", "", "", 1, "account_a", "profile_a")
	state.set_ready(1, true)

	var prefix := "casual_match_room_policy_test.member_count"
	var ok := true
	ok = qqt_check(not state.can_start(), "single member must not start match room", prefix) and ok

	state.upsert_member(2, "Beta", "", "", "", "", 2, "account_b", "profile_b")
	state.set_ready(2, true)
	ok = qqt_check(not state.can_start(), "match room must enter queue instead of starting directly", prefix) and ok
	return ok


func _test_match_ticket_claim_requires_assignment_locks() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	var claim = RoomTicketClaimScript.new()
	claim.room_kind = "casual_match_room"
	claim.assignment_id = "assign_alpha"
	claim.assignment_revision = 1
	claim.match_source = "matchmaking"
	claim.locked_map_id = "map_classic_square"
	claim.locked_rule_set_id = "ruleset_classic"
	claim.locked_mode_id = "mode_classic"
	claim.assigned_team_id = 1
	claim.expected_member_count = 4
	claim.auto_ready_on_join = true
	claim.hidden_room = true

	var prefix := "casual_match_room_policy_test.ticket_claim"
	var ok := true
	ok = qqt_check(verifier._is_valid_match_room_claim(claim), "complete match claim should be valid", prefix) and ok
	claim.assignment_id = ""
	ok = qqt_check(not verifier._is_valid_match_room_claim(claim), "match claim without assignment should be invalid", prefix) and ok
	claim.assignment_id = "assign_alpha"
	claim.expected_member_count = 0
	ok = qqt_check(not verifier._is_valid_match_room_claim(claim), "match claim without expected member count should be invalid", prefix) and ok
	return ok

