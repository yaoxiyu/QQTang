extends "res://tests/gut/base/qqt_integration_test.gd"

const ServerRoomServiceScript = preload("res://network/session/legacy/server_room_service.gd")
const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")


func test_main() -> void:
	var service = ServerRoomServiceScript.new()
	var started_snapshots: Array = []
	service.start_match_requested.connect(func(snapshot): started_snapshots.append(snapshot))

	service.room_state.ensure_room("room_alpha", 1, "matchmade_room", "")
	var claim = RoomTicketClaimScript.new()
	claim.room_kind = "matchmade_room"
	claim.assignment_id = "assign_alpha"
	claim.expected_member_count = 2
	claim.locked_map_id = service.room_state.selected_map_id
	claim.locked_rule_set_id = service.room_state.selected_rule_id
	claim.locked_mode_id = service.room_state.selected_mode_id
	service._apply_ticket_claim_to_room_state(claim)

	service.room_state.upsert_member(1, "Alpha", "", "", "", "", 1, "account_a", "profile_a")
	service.room_state.set_ready(1, true)
	service._maybe_auto_start_match()
	service.room_state.upsert_member(2, "Beta", "", "", "", "", 2, "account_b", "profile_b")
	service.room_state.set_ready(2, true)
	service._maybe_auto_start_match()

	var ok := true
	ok = qqt_check(started_snapshots.size() == 1, "full matchmade room should auto start exactly once", "matchmade_room_auto_start_test") and ok
	ok = qqt_check(service.room_state.is_matchmade_room, "room should stay in matchmade mode", "matchmade_room_auto_start_test") and ok

