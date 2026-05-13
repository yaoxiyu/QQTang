class_name BattleItemConfigBuilder
extends RefCounted

const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const ItemLoaderScript = preload("res://content/items/runtime/item_loader.gd")
const BattleItemCatalogScript = preload("res://content/items/catalog/battle_item_catalog.gd")

const DROP_PROFILE_REGISTRY := {
	"default_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"battle_item_id": "1", "weight": 30},
			{"battle_item_id": "2", "weight": 30},
			{"battle_item_id": "3", "weight": 25},
			{"battle_item_id": "6", "weight": 5},
			{"battle_item_id": "7", "weight": 5},
			{"battle_item_id": "8", "weight": 5},
		],
		"empty_weight": 50,
	},
	"classic_plus_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"battle_item_id": "1", "weight": 35},
			{"battle_item_id": "2", "weight": 35},
			{"battle_item_id": "3", "weight": 30},
			{"battle_item_id": "6", "weight": 5},
			{"battle_item_id": "7", "weight": 5},
			{"battle_item_id": "8", "weight": 5},
		],
		"empty_weight": 35,
	},
	"quick_match_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"battle_item_id": "1", "weight": 25},
			{"battle_item_id": "2", "weight": 40},
			{"battle_item_id": "3", "weight": 35},
			{"battle_item_id": "6", "weight": 5},
			{"battle_item_id": "7", "weight": 5},
			{"battle_item_id": "8", "weight": 5},
		],
		"empty_weight": 30,
	},
}


func build_for_start_config(start_config: BattleStartConfig) -> Dictionary:
	if start_config == null:
		return {}
	return build_for_rule(
		String(start_config.rule_set_id),
		String(start_config.item_spawn_profile_id)
	)


func build_for_rule(rule_set_id: String, fallback_profile_id: String = "default_items") -> Dictionary:
	var normalized_rule_key := rule_set_id.strip_edges().to_lower()
	var resolved_rule_set_id := _normalize_rule_set_id(normalized_rule_key)
	var rule_config := RuleSetCatalogScript.get_rule_metadata(resolved_rule_set_id)
	var profile_id := _resolve_profile_id(normalized_rule_key, rule_config)
	if profile_id.is_empty():
		profile_id = fallback_profile_id
	if profile_id.is_empty():
		profile_id = "default_items"

	var profile_template: Dictionary = DROP_PROFILE_REGISTRY.get(profile_id, DROP_PROFILE_REGISTRY["default_items"]).duplicate(true)
	var resolved_pool: Array[Dictionary] = []
	var enabled_items: Array[Dictionary] = []
	var items_by_type := {}
	var items_by_battle_item_id := {}
	for drop_entry in profile_template.get("drop_pool", []):
		var battle_item_id := String(drop_entry.get("battle_item_id", ""))
		if battle_item_id.is_empty():
			continue
		var item_definition: Dictionary = {}
		if BattleItemCatalogScript.has_battle_item(battle_item_id):
			item_definition = BattleItemCatalogScript.get_battle_item_entry(battle_item_id)
		elif ItemCatalogScript.has_item(battle_item_id):
			item_definition = ItemLoaderScript.load_item_definition(battle_item_id)
		else:
			continue
		if item_definition.is_empty():
			continue
		enabled_items.append(item_definition.duplicate(true))
		var item_type := int(item_definition.get("item_type", 0))
		if item_type > 0:
			items_by_type[item_type] = item_definition.duplicate(true)
		items_by_battle_item_id[battle_item_id] = item_definition.duplicate(true)
		resolved_pool.append({
			"battle_item_id": battle_item_id,
			"item_type": item_type,
			"display_name": String(item_definition.get("display_name", battle_item_id)),
			"pickup_effect_type": String(item_definition.get("pickup_effect_type", "")),
			"backpack_type": String(item_definition.get("backpack_type", "none")),
			"effect_type": String(item_definition.get("effect_type", "")),
			"effect_target": String(item_definition.get("effect_target", "")),
			"effect_mode": String(item_definition.get("effect_mode", "")),
			"effect_value": int(item_definition.get("effect_value", 0)),
			"hotkey_action": String(item_definition.get("hotkey_action", "")),
			"hotkey_spawn_battle_item_id": String(item_definition.get("hotkey_spawn_battle_item_id", "")),
			"weight": int(drop_entry.get("weight", 0)),
		})

	return {
		"profile_id": profile_id,
		"drop_enabled": bool(profile_template.get("drop_enabled", true)),
		"brick_drop_mode": String(profile_template.get("brick_drop_mode", "weighted_random")),
		"max_spawn_per_match": int(profile_template.get("max_spawn_per_match", 999)),
		"empty_weight": int(profile_template.get("empty_weight", 0)),
		"drop_pool": resolved_pool,
		"enabled_items": enabled_items,
		"items_by_type": items_by_type,
		"items_by_battle_item_id": items_by_battle_item_id,
	}


func _normalize_rule_set_id(rule_set_id: String) -> String:
	var normalized := rule_set_id.strip_edges().to_lower()
	match normalized:
		"classic":
			return "ruleset_classic"
		"classic_plus":
			return "ruleset_classic_plus"
		"quick_match":
			return "ruleset_quick_match"
		_:
			if normalized.begins_with("ruleset_"):
				return normalized
			return "ruleset_%s" % normalized if not normalized.is_empty() else normalized


func _resolve_profile_id(normalized_rule_key: String, rule_config: Dictionary) -> String:
	var profile_id := String(rule_config.get("item_drop_profile", ""))
	if not profile_id.is_empty():
		return profile_id
	match normalized_rule_key:
		"classic_plus", "ruleset_classic_plus":
			return "classic_plus_items"
		"quick_match", "ruleset_quick_match":
			return "quick_match_items"
		"classic", "ruleset_classic":
			return "default_items"
		_:
			return ""
