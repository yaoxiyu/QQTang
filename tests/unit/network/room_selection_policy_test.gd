extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSelectionPolicyScript = preload("res://network/session/runtime/room_selection_policy.gd")


class MockTicketClaim:
	var allowed_character_ids: Array[String] = ["char_huoying"]
	var allowed_character_skin_ids: Array[String] = ["skin_gold"]
	var allowed_bubble_style_ids: Array[String] = ["bubble_round"]
	var allowed_bubble_skin_ids: Array[String] = ["bubble_skin_gold"]


class MockTicketVerifier:
	func is_loadout_allowed(claim, character_id: String, character_skin_id: String, bubble_style_id: String, bubble_skin_id: String) -> bool:
		return claim.allowed_character_ids.has(character_id) \
			and claim.allowed_character_skin_ids.has(character_skin_id) \
			and claim.allowed_bubble_style_ids.has(bubble_style_id) \
			and claim.allowed_bubble_skin_ids.has(bubble_skin_id)


func test_main() -> void:
	var ok := true
	ok = _test_normalize_member_loadout_uses_character_bubble_default() and ok
	ok = _test_request_loadout_rejects_invalid_character() and ok
	ok = _test_request_loadout_checks_ticket_after_normalization() and ok


func _test_normalize_member_loadout_uses_character_bubble_default() -> bool:
	var result := RoomSelectionPolicyScript.normalize_member_loadout("char_huoying", "missing_skin", "missing_bubble", "missing_bubble_skin")
	var prefix := "room_selection_policy_test"
	var ok := true
	ok = qqt_check(String(result.get("character_id", "")) == "char_huoying", "valid character should be preserved", prefix) and ok
	ok = qqt_check(String(result.get("character_skin_id", "")) == "", "missing character skin should clear to base skin", prefix) and ok
	ok = qqt_check(String(result.get("bubble_style_id", "")) == "bubble_round", "missing bubble should use character default bubble", prefix) and ok
	ok = qqt_check(String(result.get("bubble_skin_id", "")) == "", "missing bubble skin should clear to base skin", prefix) and ok
	return ok


func _test_request_loadout_rejects_invalid_character() -> bool:
	var result := RoomSelectionPolicyScript.resolve_request_loadout({
		"character_id": "missing_character",
	})
	return qqt_check(String(result.get("error", "")) == "ROOM_MEMBER_PROFILE_INVALID", "invalid request character should reject", "room_selection_policy_test")


func _test_request_loadout_checks_ticket_after_normalization() -> bool:
	var result := RoomSelectionPolicyScript.resolve_request_loadout({
		"character_id": "char_huoying",
		"character_skin_id": "skin_gold",
		"bubble_style_id": "missing_bubble",
		"bubble_skin_id": "bubble_skin_gold",
	}, MockTicketVerifier.new(), MockTicketClaim.new())
	var prefix := "room_selection_policy_test"
	var ok := true
	ok = qqt_check(bool(result.get("ok", false)), "normalized request loadout should pass ticket allowed list", prefix) and ok
	ok = qqt_check(String(result.get("bubble_style_id", "")) == "bubble_round", "ticket check should see normalized bubble", prefix) and ok
	return ok

