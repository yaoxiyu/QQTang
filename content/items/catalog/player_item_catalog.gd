class_name PlayerItemCatalog
extends RefCounted

const PlayerItemDefinitionScript = preload("res://content/items/defs/player_item_definition.gd")

const PLAYER_ITEM_DATA_DIR := "res://content/items/data/player_item/"

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
	var dir := DirAccess.open(PLAYER_ITEM_DATA_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".remap"):
			file_name = dir.get_next()
			continue
		var resource_path := PLAYER_ITEM_DATA_DIR + file_name
		var resource := load(resource_path)
		if resource == null or not resource is PlayerItemDefinitionScript:
			file_name = dir.get_next()
			continue
		var item_def = resource as PlayerItemDefinitionScript
		var player_item_id := String(item_def.player_item_id)
		if player_item_id.is_empty():
			file_name = dir.get_next()
			continue
		var entry: Dictionary = item_def.to_catalog_entry(resource_path)
		entry["player_item_id"] = player_item_id
		_entries_by_id[player_item_id] = entry
		file_name = dir.get_next()
	dir.list_dir_end()


static func get_all_player_item_entries() -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for player_item_id in get_player_item_ids():
		var entry: Dictionary = _entries_by_id.get(player_item_id, {})
		if not entry.is_empty():
			entries.append(entry.duplicate(true))
	return entries


static func get_player_item_ids() -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for id in _entries_by_id.keys():
		ids.append(String(id))
	ids.sort()
	return ids


static func has_player_item(player_item_id: String) -> bool:
	ensure_loaded()
	return _entries_by_id.has(player_item_id)


static func get_player_item_entry(player_item_id: String) -> Dictionary:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(player_item_id, {})
	if entry.is_empty():
		return {}
	return entry.duplicate(true)


static func get_player_item_resource_path(player_item_id: String) -> String:
	ensure_loaded()
	var entry: Dictionary = _entries_by_id.get(player_item_id, {})
	if entry.is_empty():
		return ""
	return String(entry.get("resource_path", ""))
