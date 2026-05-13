class_name BattleItemConfigBuilder
extends RefCounted

const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const ItemLoaderScript = preload("res://content/items/runtime/item_loader.gd")

const DROP_PROFILE_REGISTRY := {
	"default_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"item_id": "1", "weight": 30},
			{"item_id": "2", "weight": 30},
			{"item_id": "3", "weight": 25},
				{"item_id": "6", "weight": 5},
				{"item_id": "7", "weight": 5},
				{"item_id": "8", "weight": 5},
			],
			"empty_weight": 50,
	},
	"classic_plus_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"item_id": "1", "weight": 35},
			{"item_id": "2", "weight": 35},
			{"item_id": "3", "weight": 30},
				{"item_id": "6", "weight": 5},
				{"item_id": "7", "weight": 5},
				{"item_id": "8", "weight": 5},
			],
			"empty_weight": 35,
	},
	"quick_match_items": {
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"drop_pool": [
			{"item_id": "1", "weight": 25},
			{"item_id": "2", "weight": 40},
			{"item_id": "3", "weight": 35},
				{"item_id": "6", "weight": 5},
				{"item_id": "7", "weight": 5},
				{"item_id": "8", "weight": 5},
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
	for drop_entry in profile_template.get("drop_pool", []):
		var item_id := String(drop_entry.get("item_id", ""))
		if item_id.is_empty() or not ItemCatalogScript.has_item(item_id):
			continue
		var item_definition := ItemLoaderScript.load_item_definition(item_id)
		if item_definition.is_empty():
			continue
		enabled_items.append(item_definition.duplicate(true))
		items_by_type[int(item_definition.get("item_type", 0))] = item_definition.duplicate(true)
		resolved_pool.append({
			"item_id": item_id,
			"item_type": int(item_definition.get("item_type", 0)),
			"display_name": String(item_definition.get("display_name", item_id)),
			"pickup_effect_type": String(item_definition.get("pickup_effect_type", "")),
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
