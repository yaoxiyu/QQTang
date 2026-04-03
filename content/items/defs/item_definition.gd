class_name ItemDefinition
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_path: String = ""
@export var item_type: int = 0
@export var pickup_effect_type: String = ""
@export var max_stack: int = 1
@export var rarity: String = "common"
@export var enabled: bool = true
@export var content_hash: String = ""


func to_catalog_entry(resource_path: String) -> Dictionary:
	return {
		"item_id": item_id,
		"display_name": display_name,
		"description": description,
		"resource_path": resource_path,
		"icon_path": icon_path,
		"item_type": item_type,
		"pickup_effect_type": pickup_effect_type,
		"max_stack": max_stack,
		"rarity": rarity,
		"enabled": enabled,
		"content_hash": content_hash,
	}


func to_runtime_definition(resource_path: String) -> Dictionary:
	return {
		"item_id": item_id,
		"display_name": display_name,
		"description": description,
		"resource_path": resource_path,
		"icon_path": icon_path,
		"item_type": item_type,
		"pickup_effect_type": pickup_effect_type,
		"max_stack": max_stack,
		"rarity": rarity,
		"enabled": enabled,
		"content_hash": content_hash,
	}
