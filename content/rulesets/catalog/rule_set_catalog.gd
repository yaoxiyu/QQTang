class_name RuleSetCatalog
extends RefCounted

const RuleSetDefScript = preload("res://content/rulesets/defs/rule_set_def.gd")
const DATA_DIR := "res://content/rulesets/data/rule_set"

static var _rules_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_rules_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("RuleSetCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is RuleSetDefScript:
			push_error("RuleSetCatalog failed to load rule set def: %s" % resource_path)
			continue
		var def := resource as RuleSetDef
		if def.rule_set_id.is_empty():
			push_error("RuleSetCatalog rule_set_id is empty: %s" % resource_path)
			continue
		_rules_by_id[def.rule_set_id] = def

	for rule_set_id in _rules_by_id.keys():
		_ordered_ids.append(String(rule_set_id))
	_ordered_ids.sort()


static func get_by_id(rule_set_id: String) -> RuleSetDef:
	_ensure_loaded()
	if not _rules_by_id.has(rule_set_id):
		return null
	return _rules_by_id[rule_set_id] as RuleSetDef


static func get_all() -> Array[RuleSetDef]:
	_ensure_loaded()
	var result: Array[RuleSetDef] = []
	for rule_set_id in _ordered_ids:
		result.append(_rules_by_id[rule_set_id] as RuleSetDef)
	return result


static func has_id(rule_set_id: String) -> bool:
	_ensure_loaded()
	return _rules_by_id.has(rule_set_id)


static func has_rule(rule_set_id: String) -> bool:
	return has_id(rule_set_id)


static func get_default_rule_id() -> String:
	_ensure_loaded()
	if _ordered_ids.is_empty():
		return ""
	return _ordered_ids[0]


static func get_rule_entries() -> Array:
	_ensure_loaded()
	var entries: Array = []
	for rule_set_id in _ordered_ids:
		entries.append(get_rule_metadata(rule_set_id))
	return entries


static func get_rule_metadata(rule_set_id: String) -> Dictionary:
	var def := get_by_id(rule_set_id)
	if def == null:
		return {}
	var display_name := _display_name_from_rule_set_id(def.rule_set_id)
	return {
		"id": def.rule_set_id,
		"rule_set_id": def.rule_set_id,
		"display_name": display_name,
		"version": 1,
		"description": "",
		"round_time_sec": def.time_limit_sec,
		"round_count": def.round_count,
		"respawn_enabled": def.respawn_enabled,
		"friendly_fire": def.friendly_fire,
		"sudden_death_enabled": def.sudden_death_enabled,
		"item_drop_profile": def.item_drop_profile_id,
		"item_drop_profile_id": def.item_drop_profile_id,
		"player_explosion_profile_id": def.player_explosion_profile_id,
		"bubble_explosion_profile_id": def.bubble_explosion_profile_id,
		"item_explosion_profile_id": def.item_explosion_profile_id,
		"breakable_block_explosion_profile_id": def.breakable_block_explosion_profile_id,
		"score_policy": def.score_policy,
		"player_down_policy": def.player_down_policy,
		"rescue_touch_enabled": def.rescue_touch_enabled,
		"enemy_touch_execute_enabled": def.enemy_touch_execute_enabled,
		"trapped_timeout_sec": def.trapped_timeout_sec,
		"respawn_delay_sec": def.respawn_delay_sec,
		"respawn_invincible_sec": def.respawn_invincible_sec,
		"death_display_sec": def.death_display_sec,
		"score_per_enemy_finish": def.score_per_enemy_finish,
		"score_tiebreak_policy": def.score_tiebreak_policy,
		"respawn_spawn_policy": def.respawn_spawn_policy,
		"starting_bomb_count": 1,
		"starting_firepower": 1,
		"starting_speed": 1,
		"enabled": true,
		"ui_tags": PackedStringArray(),
	}


static func _ensure_loaded() -> void:
	if _rules_by_id.is_empty():
		load_all()


static func _display_name_from_rule_set_id(rule_set_id: String) -> String:
	match rule_set_id:
		"ruleset_classic":
			return "经典模式"
		"ruleset_quick_match":
			return "快速对局"
		"ruleset_score_team":
			return "积分模式"
		_:
			return rule_set_id.replace("_", " ").capitalize()
