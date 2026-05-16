class_name BattleItemCatalog
extends RefCounted

const BattleItemDefinitionScript = preload("res://content/items/defs/battle_item_definition.gd")

const BATTLE_ITEM_DATA_DIR := "res://content/items/data/battle_item/"

static var _entries_by_id: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_scan_data_dir()


static func reload() -> void:
	_entries_by_id.clear()
	_loaded = false
	ensure_loaded()


static func _scan_data_dir() -> void:
	var dir := DirAccess.open(BATTLE_ITEM_DATA_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".remap"):
			file_name = dir.get_next()
			continue
		if file_name.ends_with(".remap"):
			file_name = file_name.trim_suffix(".remap")
		var resource_path := BATTLE_ITEM_DATA_DIR + file_name
		var resource := load(resource_path)
		if resource == null or not resource is BattleItemDefinitionScript:
			file_name = dir.get_next()
			continue
		var item_def = resource as BattleItemDefinitionScript
		var battle_item_id := String(item_def.battle_item_id)
		if battle_item_id.is_empty():
			file_name = dir.get_next()
			continue
		var entry: Dictionary = item_def.to_catalog_entry(resource_path)
		entry["battle_item_id"] = battle_item_id
		_entries_by_id[battle_item_id] = entry
		file_name = dir.get_next()
	dir.list_dir_end()


static func get_all_battle_item_entries() -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for battle_item_id in get_battle_item_ids():
		var entry: Dictionary = _entries_by_id.get(battle_item_id, {})
		if not entry.is_empty():
			entries.append(entry.duplicate(true))
	return entries


static func get_enabled_battle_item_entries() -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for entry in get_all_battle_item_entries():
		if bool(entry.get("enabled", false)):
			entries.append(entry)
	return entries


static func get_battle_item_ids() -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for id in _entries_by_id.keys():
		ids.append(String(id))
	ids.sort()
	return ids


static func has_battle_item(battle_item_id: String) -> bool:
	ensure_loaded()
	return _entries_by_id.has(battle_item_id)


static func get_battle_item_entry(battle_item_id: String) -> Dictionary:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(battle_item_id, {})
	if entry.is_empty():
		return {}
	return entry.duplicate(true)


static func get_battle_item_resource_path(battle_item_id: String) -> String:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(battle_item_id, {})
	if entry.is_empty():
		return ""
	return String(entry.get("resource_path", ""))
