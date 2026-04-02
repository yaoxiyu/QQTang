class_name BattleSimConfigBuilder
extends RefCounted

const BattleItemConfigBuilderScript = preload("res://gameplay/battle/config/battle_item_config_builder.gd")


func build_for_start_config(start_config: BattleStartConfig) -> SimConfig:
	var sim_config := SimConfig.new()
	if start_config == null:
		return sim_config
	var item_builder = BattleItemConfigBuilderScript.new()
	var item_config: Dictionary = item_builder.build_for_start_config(start_config)
	sim_config.item_defs = item_config.get("items_by_type", {}).duplicate(true)
	sim_config.system_flags["item_drop_profile"] = {
		"profile_id": String(item_config.get("profile_id", "")),
		"drop_enabled": bool(item_config.get("drop_enabled", true)),
		"brick_drop_mode": String(item_config.get("brick_drop_mode", "weighted_random")),
		"max_spawn_per_match": int(item_config.get("max_spawn_per_match", 999)),
		"empty_weight": int(item_config.get("empty_weight", 0)),
		"drop_pool": item_config.get("drop_pool", []).duplicate(true),
	}
	return sim_config
