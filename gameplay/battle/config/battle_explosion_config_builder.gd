class_name BattleExplosionConfigBuilder
extends RefCounted

const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ExplosionReactionProfileRegistryScript = preload("res://gameplay/simulation/explosion/explosion_reaction_profile_registry.gd")

const DEFAULT_PLAYER_PROFILE_ID := "player_kill_default"
const DEFAULT_BUBBLE_PROFILE_ID := "bubble_chain_immediate"
const DEFAULT_ITEM_PROFILE_ID := "item_destroy_default"
const DEFAULT_BREAKABLE_BLOCK_PROFILE_ID := "breakable_destroy_stop"


func build_for_rule(rule_set_id: String) -> Dictionary:
	var metadata: Dictionary = RuleSetCatalogScript.get_rule_metadata(rule_set_id)

	var player_profile_id := _resolve_profile_id(
		metadata,
		"player_explosion_profile_id",
		DEFAULT_PLAYER_PROFILE_ID
	)
	var bubble_profile_id := _resolve_profile_id(
		metadata,
		"bubble_explosion_profile_id",
		DEFAULT_BUBBLE_PROFILE_ID
	)
	var item_profile_id := _resolve_profile_id(
		metadata,
		"item_explosion_profile_id",
		DEFAULT_ITEM_PROFILE_ID
	)
	var breakable_block_profile_id := _resolve_profile_id(
		metadata,
		"breakable_block_explosion_profile_id",
		DEFAULT_BREAKABLE_BLOCK_PROFILE_ID
	)

	return {
		"player_profile_id": player_profile_id,
		"bubble_profile_id": bubble_profile_id,
		"item_profile_id": item_profile_id,
		"breakable_block_profile_id": breakable_block_profile_id,
		"player_profile": ExplosionReactionProfileRegistryScript.get_player_profile(player_profile_id),
		"bubble_profile": ExplosionReactionProfileRegistryScript.get_bubble_profile(bubble_profile_id),
		"item_profile": ExplosionReactionProfileRegistryScript.get_item_profile(item_profile_id),
		"breakable_block_profile": ExplosionReactionProfileRegistryScript.get_breakable_block_profile(breakable_block_profile_id),
	}


func build_for_start_config(start_config: BattleStartConfig) -> Dictionary:
	if start_config == null:
		return build_for_rule("")
	return build_for_rule(String(start_config.rule_set_id))


func _resolve_profile_id(metadata: Dictionary, key: String, fallback_id: String) -> String:
	var value := String(metadata.get(key, ""))
	if value.is_empty():
		return fallback_id
	return value
