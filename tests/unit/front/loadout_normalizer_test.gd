extends "res://tests/gut/base/qqt_unit_test.gd"

const LoadoutNormalizerScript = preload("res://app/front/loadout/loadout_normalizer.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const RoomTicketRequestScript = preload("res://app/front/auth/room_ticket_request.gd")


func test_main() -> void:
	var ok := true
	ok = _test_resolve_from_owned_profile_defaults() and ok
	ok = _test_invalid_profile_values_fall_back_to_owned_catalog_assets() and ok
	ok = _test_apply_to_ticket_request_uses_normalized_values() and ok


func _test_resolve_from_owned_profile_defaults() -> bool:
	var profile = _profile("char_huoying", "skin_gold", "bubble_round", "bubble_skin_gold")
	var result = LoadoutNormalizerScript.resolve_from_profile(profile)
	var prefix := "loadout_normalizer_test"
	var ok := true
	ok = qqt_check(result.character_id == "char_huoying", "valid character should be preserved", prefix) and ok
	ok = qqt_check(result.character_skin_id == "skin_gold", "valid character skin should be preserved", prefix) and ok
	ok = qqt_check(result.bubble_style_id == "bubble_round", "valid bubble style should be preserved", prefix) and ok
	ok = qqt_check(result.bubble_skin_id == "bubble_skin_gold", "valid bubble skin should be preserved", prefix) and ok
	ok = qqt_check(result.changed_fields.is_empty(), "valid loadout should not mark changed fields", prefix) and ok
	return ok


func _test_invalid_profile_values_fall_back_to_owned_catalog_assets() -> bool:
	var profile = _profile("missing_character", "missing_skin", "missing_bubble", "missing_bubble_skin")
	var result = LoadoutNormalizerScript.resolve_from_profile(profile)
	var prefix := "loadout_normalizer_test"
	var ok := true
	ok = qqt_check(result.character_id == "char_huoying", "invalid character should use owned catalog character", prefix) and ok
	ok = qqt_check(result.character_skin_id == "skin_gold", "invalid character skin should use owned catalog skin", prefix) and ok
	ok = qqt_check(result.bubble_style_id == "bubble_round", "invalid bubble should use owned catalog bubble", prefix) and ok
	ok = qqt_check(result.bubble_skin_id == "bubble_skin_gold", "invalid bubble skin should use owned catalog skin", prefix) and ok
	ok = qqt_check(result.changed_fields.size() == 4, "all invalid fields should be marked changed", prefix) and ok
	return ok


func _test_apply_to_ticket_request_uses_normalized_values() -> bool:
	var profile = _profile("missing_character", "skin_gold", "missing_bubble", "bubble_skin_gold")
	var request := RoomTicketRequestScript.new()
	LoadoutNormalizerScript.apply_to_ticket_request(request, profile)
	var prefix := "loadout_normalizer_test"
	var ok := true
	ok = qqt_check(request.selected_character_id == "char_huoying", "ticket should receive normalized character", prefix) and ok
	ok = qqt_check(request.selected_bubble_style_id == "bubble_round", "ticket should receive normalized bubble", prefix) and ok
	return ok


func _profile(character_id: String, character_skin_id: String, bubble_style_id: String, bubble_skin_id: String):
	var profile = PlayerProfileStateScript.new()
	profile.default_character_id = character_id
	profile.default_character_skin_id = character_skin_id
	profile.default_bubble_style_id = bubble_style_id
	profile.default_bubble_skin_id = bubble_skin_id
	profile.owned_character_ids = _strings(["char_huoying"])
	profile.owned_character_skin_ids = _strings(["skin_gold"])
	profile.owned_bubble_style_ids = _strings(["bubble_round"])
	profile.owned_bubble_skin_ids = _strings(["bubble_skin_gold"])
	return profile


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

