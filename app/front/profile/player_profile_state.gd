class_name PlayerProfileState
extends RefCounted

var profile_id: String = ""
var nickname: String = "Player1"
var default_character_id: String = ""
var default_character_skin_id: String = ""
var default_bubble_style_id: String = ""
var default_bubble_skin_id: String = ""
var preferred_map_id: String = ""
var preferred_rule_set_id: String = ""
var preferred_mode_id: String = ""


func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"nickname": nickname,
		"default_character_id": default_character_id,
		"default_character_skin_id": default_character_skin_id,
		"default_bubble_style_id": default_bubble_style_id,
		"default_bubble_skin_id": default_bubble_skin_id,
		"preferred_map_id": preferred_map_id,
		"preferred_rule_set_id": preferred_rule_set_id,
		"preferred_mode_id": preferred_mode_id,
	}


static func from_dict(data: Dictionary) -> PlayerProfileState:
	var state := PlayerProfileState.new()
	state.profile_id = String(data.get("profile_id", ""))
	state.nickname = String(data.get("nickname", "Player1"))
	state.default_character_id = String(data.get("default_character_id", ""))
	state.default_character_skin_id = String(data.get("default_character_skin_id", ""))
	state.default_bubble_style_id = String(data.get("default_bubble_style_id", ""))
	state.default_bubble_skin_id = String(data.get("default_bubble_skin_id", ""))
	state.preferred_map_id = String(data.get("preferred_map_id", ""))
	state.preferred_rule_set_id = String(data.get("preferred_rule_set_id", ""))
	state.preferred_mode_id = String(data.get("preferred_mode_id", ""))
	return state


func duplicate_deep() -> PlayerProfileState:
	return PlayerProfileState.from_dict(to_dict())
