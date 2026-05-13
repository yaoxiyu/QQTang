class_name PlayerItemDefinition
extends Resource

@export var player_item_id: String = ""
@export var display_name: String = ""
@export var item_type: String = ""
@export var icon_path: String = ""
@export var rarity: String = "common"
@export var target_character_id: String = ""
@export var skin_slot: String = ""
@export var stackable: bool = false
@export var max_stack: int = 0
@export var content_hash: String = ""


func to_catalog_entry(resource_path: String) -> Dictionary:
	return {
		"player_item_id": player_item_id,
		"display_name": display_name,
		"item_type": item_type,
		"icon_path": icon_path,
		"rarity": rarity,
		"target_character_id": target_character_id,
		"skin_slot": skin_slot,
		"stackable": stackable,
		"max_stack": max_stack,
		"resource_path": resource_path,
		"content_hash": content_hash,
	}


func to_runtime_definition(resource_path: String) -> Dictionary:
	return to_catalog_entry(resource_path)
