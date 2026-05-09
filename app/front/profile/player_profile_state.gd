class_name PlayerProfileState
extends RefCounted

const ROOM_RANDOM_CHARACTER_ID := "12301"

var profile_id: String = ""
var account_id: String = ""
var nickname: String = "Player1"
var avatar_id: String = ""
var title_id: String = ""
var default_character_id: String = ""
var default_bubble_style_id: String = ""
var preferred_map_id: String = ""
var preferred_rule_set_id: String = ""
var preferred_mode_id: String = ""
var owned_character_ids: Array[String] = []
var owned_bubble_style_ids: Array[String] = []
var profile_version: int = 0
var owned_asset_revision: int = 0
var profile_source: String = "local_cache"
var last_sync_msec: int = 0


func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"account_id": account_id,
		"nickname": nickname,
		"avatar_id": avatar_id,
		"title_id": title_id,
		"default_character_id": resolve_default_character_id(default_character_id),
		"default_bubble_style_id": default_bubble_style_id,
		"preferred_map_id": preferred_map_id,
		"preferred_rule_set_id": preferred_rule_set_id,
		"preferred_mode_id": preferred_mode_id,
		"owned_character_ids": owned_character_ids.duplicate(),
		"owned_bubble_style_ids": owned_bubble_style_ids.duplicate(),
		"profile_version": profile_version,
		"owned_asset_revision": owned_asset_revision,
		"profile_source": profile_source,
		"last_sync_msec": last_sync_msec,
	}


static func from_dict(data: Dictionary) -> PlayerProfileState:
	var state := PlayerProfileState.new()
	state.profile_id = String(data.get("profile_id", ""))
	state.account_id = String(data.get("account_id", ""))
	state.nickname = String(data.get("nickname", "Player1"))
	state.avatar_id = String(data.get("avatar_id", ""))
	state.title_id = String(data.get("title_id", ""))
	state.default_character_id = resolve_default_character_id(String(data.get("default_character_id", "")))
	state.default_bubble_style_id = String(data.get("default_bubble_style_id", ""))
	state.preferred_map_id = String(data.get("preferred_map_id", ""))
	state.preferred_rule_set_id = String(data.get("preferred_rule_set_id", ""))
	state.preferred_mode_id = String(data.get("preferred_mode_id", ""))
	state.owned_character_ids = _to_string_array(data.get("owned_character_ids", []))
	state.owned_bubble_style_ids = _to_string_array(data.get("owned_bubble_style_ids", []))
	state.profile_version = int(data.get("profile_version", 0))
	state.owned_asset_revision = int(data.get("owned_asset_revision", 0))
	state.profile_source = String(data.get("profile_source", "local_cache"))
	state.last_sync_msec = int(data.get("last_sync_msec", 0))
	return state


func duplicate_deep() -> PlayerProfileState:
	return PlayerProfileState.from_dict(to_dict())


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result


static func resolve_default_character_id(character_id: String) -> String:
	var normalized := character_id.strip_edges()
	return ROOM_RANDOM_CHARACTER_ID if normalized.is_empty() else normalized
