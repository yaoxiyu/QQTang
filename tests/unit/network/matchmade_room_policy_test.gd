extends Node

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")
const RoomTicketVerifierScript = preload("res://network/session/auth/room_ticket_verifier.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var ok := true
	ok = _test_matchmade_selection_is_locked() and ok
	ok = _test_matchmade_room_requires_expected_member_count() and ok
	ok = _test_matchmade_ticket_claim_requires_assignment_locks() and ok
	if ok:
		print("matchmade_room_policy_test: PASS")


func _test_matchmade_selection_is_locked() -> bool:
	var state = RoomServerStateScript.new()
	state.ensure_room("room_match", 1, "matchmade_room", "Ranked Room")
	var locked_map: String = String(state.selected_map_id)
	var locked_rule: String = String(state.selected_rule_id)
	var locked_mode: String = String(state.selected_mode_id)
	state.locked_map_id = locked_map
	state.locked_rule_set_id = locked_rule
	state.locked_mode_id = locked_mode
	state.is_matchmade_room = true

	state.set_selection("fake_map", "fake_rule", "fake_mode")

	var prefix := "matchmade_room_policy_test.selection"
	var ok := true
	ok = TestAssert.is_true(state.selected_map_id == locked_map, "matchmade room should keep locked map", prefix) and ok
	ok = TestAssert.is_true(state.selected_rule_id == locked_rule, "matchmade room should keep locked rule", prefix) and ok
	ok = TestAssert.is_true(state.selected_mode_id == locked_mode, "matchmade room should keep locked mode", prefix) and ok
	return ok


func _test_matchmade_room_requires_expected_member_count() -> bool:
	var state = RoomServerStateScript.new()
	state.ensure_room("room_match", 1, "matchmade_room", "Ranked Room")
	state.is_matchmade_room = true
	state.expected_member_count = 2
	state.upsert_member(1, "Alpha", "", "", "", "", 1, "account_a", "profile_a")
	state.set_ready(1, true)

	var prefix := "matchmade_room_policy_test.member_count"
	var ok := true
	ok = TestAssert.is_true(not state.can_start(), "single member must not start matchmade room", prefix) and ok

	state.upsert_member(2, "Beta", "", "", "", "", 2, "account_b", "profile_b")
	state.set_ready(2, true)
	ok = TestAssert.is_true(state.can_start(), "full ready roster should allow match start", prefix) and ok
	return ok


func _test_matchmade_ticket_claim_requires_assignment_locks() -> bool:
	var verifier = RoomTicketVerifierScript.new()
	var claim = RoomTicketClaimScript.new()
	claim.room_kind = "matchmade_room"
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

	var prefix := "matchmade_room_policy_test.ticket_claim"
	var ok := true
	ok = TestAssert.is_true(verifier._is_valid_matchmade_claim(claim), "complete matchmade claim should be valid", prefix) and ok
	claim.assignment_id = ""
	ok = TestAssert.is_true(not verifier._is_valid_matchmade_claim(claim), "matchmade claim without assignment should be invalid", prefix) and ok
	claim.assignment_id = "assign_alpha"
	claim.expected_member_count = 0
	ok = TestAssert.is_true(not verifier._is_valid_matchmade_claim(claim), "matchmade claim without expected member count should be invalid", prefix) and ok
	return ok
