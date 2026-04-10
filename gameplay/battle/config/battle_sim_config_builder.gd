class_name BattleSimConfigBuilder
extends RefCounted

const BattleItemConfigBuilderScript = preload("res://gameplay/battle/config/battle_item_config_builder.gd")
const BattleExplosionConfigBuilderScript = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")


func build_for_start_config(start_config: BattleStartConfig) -> SimConfig:
	var sim_config := SimConfig.new()
	if start_config == null:
		return sim_config
	var item_builder = BattleItemConfigBuilderScript.new()
	var explosion_builder = BattleExplosionConfigBuilderScript.new()
	var item_config: Dictionary = item_builder.build_for_start_config(start_config)
	var explosion_config: Dictionary = explosion_builder.build_for_start_config(start_config)
	var rule_set_def: RuleSetDef = RuleSetCatalogScript.get_by_id(String(start_config.rule_set_id))
	sim_config.item_defs = item_config.get("items_by_type", {}).duplicate(true)
	sim_config.system_flags["item_drop_profile"] = {
		"profile_id": String(item_config.get("profile_id", "")),
		"drop_enabled": bool(item_config.get("drop_enabled", true)),
		"brick_drop_mode": String(item_config.get("brick_drop_mode", "weighted_random")),
		"max_spawn_per_match": int(item_config.get("max_spawn_per_match", 999)),
		"empty_weight": int(item_config.get("empty_weight", 0)),
		"drop_pool": item_config.get("drop_pool", []).duplicate(true),
	}
	sim_config.system_flags["explosion_reaction"] = explosion_config.duplicate(true)
	sim_config.system_flags["rule_set"] = _build_rule_set_flags(rule_set_def)
	sim_config.system_flags["spawn_assignments"] = start_config.spawn_assignments.duplicate(true)
	sim_config.system_flags["player_slots"] = start_config.player_slots.duplicate(true)
	return sim_config


func _build_rule_set_flags(rule_set_def: RuleSetDef) -> Dictionary:
	if rule_set_def == null:
		return {}
	return {
		"rule_set_id": String(rule_set_def.rule_set_id),
		"respawn_enabled": bool(rule_set_def.respawn_enabled),
		"score_policy": String(rule_set_def.score_policy),
		"rescue_touch_enabled": bool(rule_set_def.rescue_touch_enabled),
		"enemy_touch_execute_enabled": bool(rule_set_def.enemy_touch_execute_enabled),
		"respawn_delay_sec": int(rule_set_def.respawn_delay_sec),
		"respawn_invincible_sec": int(rule_set_def.respawn_invincible_sec),
		"score_per_enemy_finish": int(rule_set_def.score_per_enemy_finish),
		"score_tiebreak_policy": String(rule_set_def.score_tiebreak_policy),
		"respawn_spawn_policy": String(rule_set_def.respawn_spawn_policy),
	}
