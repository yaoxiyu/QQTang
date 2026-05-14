class_name BattleItemDefinition
extends Resource

@export var battle_item_id: String = ""
@export var item_type: int = 0
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
@export var stand_source: String = ""
@export var trigger_source: String = ""
@export var enabled: bool = true
@export var backpack_type: String = "none"
@export var pool_category: String = ""
@export var apply_on_pickup: bool = true
@export var effect_type: String = ""
@export var effect_target: String = ""
@export var effect_mode: String = ""
@export var effect_value: int = 0
@export var hotkey_action: String = ""
@export var hotkey_spawn_battle_item_id: String = ""
@export var content_hash: String = ""

# Derived paths set by generator (not exported)
var stand_anim_path: String = ""
var trigger_anim_path: String = ""
var icon_path: String = ""


func to_catalog_entry(resource_path: String) -> Dictionary:
	return {
		"battle_item_id": battle_item_id,
		"item_type": item_type,
		"display_name": display_name,
		"description": description,
		"rarity": rarity,
		"stand_source": stand_source,
		"trigger_source": trigger_source,
		"enabled": enabled,
		"backpack_type": backpack_type,
		"pool_category": pool_category,
		"apply_on_pickup": apply_on_pickup,
		"effect_type": effect_type,
		"effect_target": effect_target,
		"effect_mode": effect_mode,
		"effect_value": effect_value,
		"hotkey_action": hotkey_action,
		"hotkey_spawn_battle_item_id": hotkey_spawn_battle_item_id,
		"stand_anim_path": stand_anim_path,
		"trigger_anim_path": trigger_anim_path,
		"icon_path": icon_path,
		"resource_path": resource_path,
		"content_hash": content_hash,
	}


func to_runtime_definition(resource_path: String) -> Dictionary:
	return to_catalog_entry(resource_path)
