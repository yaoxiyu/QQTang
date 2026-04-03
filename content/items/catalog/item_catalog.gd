class_name ItemCatalog
extends RefCounted

const ItemDefinitionScript = preload("res://content/items/defs/item_definition.gd")

const ITEM_REGISTRY := {
	"bomb_up": {
		"display_name": "Bomb Up",
		"resource_path": "res://content/items/data/item/bomb_up_item.tres",
		"is_default_enabled": true,
	},
	"power_up": {
		"display_name": "Power Up",
		"resource_path": "res://content/items/data/item/power_up_item.tres",
		"is_default_enabled": true,
	},
	"speed_up": {
		"display_name": "Speed Up",
		"resource_path": "res://content/items/data/item/speed_up_item.tres",
		"is_default_enabled": true,
	},
}


static func get_all_item_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id in get_item_ids():
		var entry := get_item_entry(item_id)
		if not entry.is_empty():
			entries.append(entry)
	return entries


static func get_enabled_item_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in get_all_item_entries():
		if bool(entry.get("enabled", false)):
			entries.append(entry)
	return entries


static func get_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for item_id in ITEM_REGISTRY.keys():
		item_ids.append(String(item_id))
	item_ids.sort()
	return item_ids


static func has_item(item_id: String) -> bool:
	return ITEM_REGISTRY.has(item_id)


static func get_item_entry(item_id: String) -> Dictionary:
	if not has_item(item_id):
		return {}
	var entry: Dictionary = ITEM_REGISTRY[item_id]
	var resource_path := String(entry.get("resource_path", ""))
	var resource := load(resource_path)
	if resource == null or not resource is ItemDefinitionScript:
		return {}
	var item_definition = resource
	var catalog_entry: Dictionary = item_definition.to_catalog_entry(resource_path)
	catalog_entry["item_id"] = item_id
	catalog_entry["display_name"] = String(entry.get("display_name", catalog_entry.get("display_name", item_id)))
	if not catalog_entry.has("enabled"):
		catalog_entry["enabled"] = bool(entry.get("is_default_enabled", true))
	return catalog_entry


static func get_item_resource_path(item_id: String) -> String:
	if not has_item(item_id):
		return ""
	return String(ITEM_REGISTRY[item_id].get("resource_path", ""))


static func get_item_entry_by_type(item_type: int) -> Dictionary:
	for item_id in get_item_ids():
		var entry := get_item_entry(item_id)
		if int(entry.get("item_type", 0)) == item_type:
			return entry
	return {}
