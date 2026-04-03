class_name ItemLoader
extends RefCounted

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const ItemDefinitionScript = preload("res://content/items/defs/item_definition.gd")


static func load_item_definition(item_id: String) -> Dictionary:
	if item_id.is_empty() or not ItemCatalogScript.has_item(item_id):
		return {}
	var resource_path := ItemCatalogScript.get_item_resource_path(item_id)
	if resource_path.is_empty():
		return {}
	var resource := load(resource_path)
	if resource == null or not resource is ItemDefinitionScript:
		return {}
	var item_definition = resource
	var runtime_definition: Dictionary = item_definition.to_runtime_definition(resource_path)
	runtime_definition["item_id"] = item_id
	return runtime_definition if _validate_item_definition(runtime_definition) else {}


static func load_all_enabled_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for entry in ItemCatalogScript.get_enabled_item_entries():
		var item_id := String(entry.get("item_id", ""))
		var definition := load_item_definition(item_id)
		if not definition.is_empty():
			items.append(definition)
	return items


static func build_item_runtime_manifest() -> Dictionary:
	var items := load_all_enabled_items()
	var items_by_id := {}
	var items_by_type := {}
	for item in items:
		var item_id := String(item.get("item_id", ""))
		var item_type := int(item.get("item_type", 0))
		items_by_id[item_id] = item.duplicate(true)
		items_by_type[item_type] = item.duplicate(true)
	return {
		"items": items,
		"items_by_id": items_by_id,
		"items_by_type": items_by_type,
	}


static func _validate_item_definition(item_definition: Dictionary) -> bool:
	if String(item_definition.get("item_id", "")).is_empty():
		return false
	if String(item_definition.get("display_name", "")).is_empty():
		return false
	if int(item_definition.get("item_type", 0)) <= 0:
		return false
	if String(item_definition.get("pickup_effect_type", "")).is_empty():
		return false
	if int(item_definition.get("max_stack", 0)) <= 0:
		return false
	if String(item_definition.get("content_hash", "")).is_empty():
		return false
	return true
