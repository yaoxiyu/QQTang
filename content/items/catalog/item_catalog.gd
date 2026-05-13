class_name ItemCatalog
extends RefCounted

const ItemDefinitionScript = preload("res://content/items/defs/item_definition.gd")

const ITEM_DATA_DIR := "res://content/items/data/item/"

static var _entries_by_id: Dictionary = {}
static var _entries_by_type: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_scan_data_dir()


static func reload() -> void:
	_entries_by_id.clear()
	_entries_by_type.clear()
	_loaded = false
	ensure_loaded()


static func _scan_data_dir() -> void:
	var dir := DirAccess.open(ITEM_DATA_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".remap"):
			file_name = dir.get_next()
			continue
		var resource_path := ITEM_DATA_DIR + file_name
		var resource := load(resource_path)
		if resource == null or not resource is ItemDefinitionScript:
			file_name = dir.get_next()
			continue
		var item_def = resource as ItemDefinitionScript
		var item_id := String(item_def.item_id)
		if item_id.is_empty():
			file_name = dir.get_next()
			continue
		var entry: Dictionary = item_def.to_catalog_entry(resource_path)
		entry["item_id"] = item_id

		_entries_by_id[item_id] = entry
		var item_type := int(entry.get("item_type", 0))
		if item_type > 0:
			_entries_by_type[item_type] = entry

		file_name = dir.get_next()
	dir.list_dir_end()


static func get_all_item_entries() -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for item_id in get_item_ids():
		var entry: Dictionary = _entries_by_id.get(item_id, {})
		if not entry.is_empty():
			entries.append(entry.duplicate(true))
	return entries


static func get_enabled_item_entries() -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for entry in get_all_item_entries():
		if bool(entry.get("enabled", false)):
			entries.append(entry)
	return entries


static func get_item_ids() -> Array[String]:
	ensure_loaded()
	var item_ids: Array[String] = []
	for item_id in _entries_by_id.keys():
		item_ids.append(String(item_id))
	item_ids.sort()
	return item_ids


static func has_item(item_id: String) -> bool:
	ensure_loaded()
	return _entries_by_id.has(item_id)


static func get_item_entry(item_id: String) -> Dictionary:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(item_id, {})
	if entry.is_empty():
		return {}
	return entry.duplicate(true)


static func get_item_resource_path(item_id: String) -> String:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(item_id, {})
	if entry.is_empty():
		return ""
	return String(entry.get("resource_path", ""))


static func get_item_entry_by_type(item_type: int) -> Dictionary:
	ensure_loaded()
	var entry: Dictionary = _entries_by_type.get(item_type, {})
	if entry.is_empty():
		return {}
	return entry.duplicate(true)
