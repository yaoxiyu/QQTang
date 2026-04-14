extends Node

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const RoomResumeValidatorScript = preload("res://network/session/runtime/room_resume_validator.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class MockTicketClaim:
	var account_id: String = ""
	var profile_id: String = ""


func _ready() -> void:
	var ok := true
	ok = _test_validate_accepts_matching_resume() and ok
	ok = _test_validate_rejects_invalid_token() and ok
	ok = _test_validate_rejects_account_mismatch() and ok
	if ok:
		print("room_resume_validator_test: PASS")


func _test_validate_accepts_matching_resume() -> bool:
	var fixture := _create_fixture()
	var validator := RoomResumeValidatorScript.new()
	var result := validator.validate(fixture["state"], fixture["message"], fixture["claim"])
	return TestAssert.is_true(bool(result.get("ok", false)), "matching resume should validate", "room_resume_validator_test")


func _test_validate_rejects_invalid_token() -> bool:
	var fixture := _create_fixture()
	var message: Dictionary = fixture["message"]
	message["reconnect_token"] = "wrong_token"
	var validator := RoomResumeValidatorScript.new()
	var result := validator.validate(fixture["state"], message, fixture["claim"])
	return TestAssert.is_true(String(result.get("error", "")) == "RECONNECT_TOKEN_INVALID", "invalid token should reject", "room_resume_validator_test")


func _test_validate_rejects_account_mismatch() -> bool:
	var fixture := _create_fixture()
	var claim: MockTicketClaim = fixture["claim"]
	claim.account_id = "other_account"
	var validator := RoomResumeValidatorScript.new()
	var result := validator.validate(fixture["state"], fixture["message"], claim)
	return TestAssert.is_true(String(result.get("error", "")) == "ROOM_TICKET_ACCOUNT_MISMATCH", "account mismatch should reject", "room_resume_validator_test")


func _create_fixture() -> Dictionary:
	var state := RoomServerStateScript.new()
	state.ensure_room("room_resume", 2, "private_room", "Resume Room")
	var binding := state.create_member_binding(2, "Player2", "hero_default", "", "", "", 1, "account_2", "profile_2")
	var token := String(binding.reconnect_token)
	var claim := MockTicketClaim.new()
	claim.account_id = "account_2"
	claim.profile_id = "profile_2"
	return {
		"state": state,
		"claim": claim,
		"message": {
			"room_id": "room_resume",
			"member_id": binding.member_id,
			"reconnect_token": token,
			"match_id": "",
		},
	}
