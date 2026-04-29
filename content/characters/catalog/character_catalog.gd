class_name CharacterCatalog
extends RefCounted

const CharacterDefScript = preload("res://content/characters/defs/character_def.gd")
const CharacterStatsDefScript = preload("res://content/characters/defs/character_stats_def.gd")
const CharacterPresentationDefScript = preload("res://content/characters/defs/character_presentation_def.gd")
const GeneratedCatalogIndexLoaderScript = preload("res://content/catalog_index/generated_catalog_index_loader.gd")

const CHARACTER_DIR := "res://content/characters/data/character"
const STATS_DIR := "res://content/characters/data/stats"
const PRESENTATION_DIR := "res://content/characters/data/presentation"

const LEGACY_CHARACTER_REGISTRY := {}

static var _character_registry: Dictionary = {}
static var _ordered_character_ids: Array[String] = []


static func load_all() -> void:
	_character_registry.clear()
	_ordered_character_ids.clear()

	if GeneratedCatalogIndexLoaderScript.has_index("characters"):
		if _load_from_generated_index():
			return

	var stats_by_id := _scan_stats_registry()
	var presentations_by_id := _scan_presentation_registry()

	if DirAccess.dir_exists_absolute(CHARACTER_DIR):
		for file_name in DirAccess.get_files_at(CHARACTER_DIR):
			if not file_name.ends_with(".tres"):
				continue
			var resource_path := "%s/%s" % [CHARACTER_DIR, file_name]
			var resource := load(resource_path)
			if resource == null or not resource is CharacterDefScript:
				push_error("CharacterCatalog failed to load CharacterDef: %s" % resource_path)
				continue
			var def := resource as CharacterDef
			var character_id := String(def.character_id)
			if character_id.is_empty():
				push_error("CharacterCatalog character_id is empty: %s" % resource_path)
				continue
			_character_registry[character_id] = {
				"display_name": String(def.display_name if not def.display_name.is_empty() else character_id),
				"def_resource_path": resource_path,
				"stats_resource_path": String(stats_by_id.get(def.stats_id, "")),
				"presentation_resource_path": String(presentations_by_id.get(def.presentation_id, "")),
				"selection_order": def.selection_order,
			}

	if _character_registry.is_empty():
		for character_id in LEGACY_CHARACTER_REGISTRY.keys():
			_character_registry[String(character_id)] = LEGACY_CHARACTER_REGISTRY[character_id].duplicate(true)

	_sort_loaded_characters()


static func _load_from_generated_index() -> bool:
	var entries := GeneratedCatalogIndexLoaderScript.load_entries("characters")
	if entries.is_empty():
		return false
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var character_id := String(entry.get("id", ""))
		if character_id.is_empty():
			continue
		_character_registry[character_id] = {
			"display_name": String(entry.get("display_name", character_id)),
			"def_resource_path": String(entry.get("def_resource_path", "")),
			"stats_resource_path": String(entry.get("stats_resource_path", "")),
			"presentation_resource_path": String(entry.get("presentation_resource_path", "")),
			"selection_order": int(entry.get("selection_order", 999999)),
			"content_hash": String(entry.get("content_hash", "")),
		}
	_sort_loaded_characters()
	return not _character_registry.is_empty()


static func _sort_loaded_characters() -> void:
	_ordered_character_ids.clear()
	var sortable_entries: Array[Dictionary] = []
	for character_id in _character_registry.keys():
		var entry: Dictionary = _character_registry[character_id]
		sortable_entries.append({
			"id": String(character_id),
			"selection_order": int(entry.get("selection_order", 999999)),
			"display_name": String(entry.get("display_name", character_id)),
		})
	sortable_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(a.get("selection_order", 999999))
		var order_b := int(b.get("selection_order", 999999))
		if order_a == order_b:
			return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0
		return order_a < order_b
	)

	for item in sortable_entries:
		_ordered_character_ids.append(String(item.get("id", "")))


static func get_character_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_character_ids.duplicate()


static func get_character_entries() -> Array[Dictionary]:
	_ensure_loaded()
	var entries: Array[Dictionary] = []
	for character_id in _ordered_character_ids:
		var entry := get_character_metadata(character_id)
		if entry.is_empty():
			continue
		entries.append({
			"id": character_id,
			"display_name": String(entry.get("display_name", character_id)),
			"version": int(entry.get("version", 1)),
			"content_hash": String(entry.get("content_hash", "")),
			"base_bomb_count": int(entry.get("base_bomb_count", 0)),
			"base_firepower": int(entry.get("base_firepower", 0)),
			"base_move_speed": int(entry.get("base_move_speed", 0)),
			"initial_bubble_count": int(entry.get("initial_bubble_count", entry.get("base_bomb_count", 0))),
			"max_bubble_count": int(entry.get("max_bubble_count", 0)),
			"initial_bubble_power": int(entry.get("initial_bubble_power", entry.get("base_firepower", 0))),
			"max_bubble_power": int(entry.get("max_bubble_power", 0)),
			"initial_move_speed": int(entry.get("initial_move_speed", entry.get("base_move_speed", 0))),
			"max_move_speed": int(entry.get("max_move_speed", 0)),
			"selection_order": int(_character_registry[character_id].get("selection_order", 999999)),
		})
	return entries


static func has_character(character_id: String) -> bool:
	_ensure_loaded()
	return _character_registry.has(character_id)


static func get_default_character_id() -> String:
	_ensure_loaded()
	if _ordered_character_ids.is_empty():
		return ""
	return _ordered_character_ids[0]


static func get_character_entry(character_id: String) -> Dictionary:
	_ensure_loaded()
	if not _character_registry.has(character_id):
		return {}
	return (_character_registry[character_id] as Dictionary).duplicate(true)


static func get_character_metadata(character_id: String) -> Dictionary:
	_ensure_loaded()
	if not _character_registry.has(character_id):
		return {}
	var entry: Dictionary = _character_registry[character_id]
	var character_def := _load_character_def(entry)
	var stats_def := _load_character_stats(entry)
	var presentation_def := _load_character_presentation(entry)
	if character_def == null or stats_def == null or presentation_def == null:
		return {}
	var display_name := String(character_def.display_name if not character_def.display_name.is_empty() else presentation_def.display_name)
	if display_name.is_empty():
		display_name = String(entry.get("display_name", character_id))
	return {
		"id": character_id,
		"character_id": String(character_def.character_id if not character_def.character_id.is_empty() else character_id),
		"display_name": display_name,
		"version": 1,
		"content_hash": _resolve_content_hash(
			character_id,
			character_def.content_hash,
			stats_def.content_hash,
			presentation_def.content_hash
		),
		"base_bomb_count": stats_def.base_bomb_count,
		"base_firepower": stats_def.base_firepower,
		"base_move_speed": stats_def.base_move_speed,
		"initial_bubble_count": stats_def.initial_bubble_count,
		"max_bubble_count": stats_def.max_bubble_count,
		"initial_bubble_power": stats_def.initial_bubble_power,
		"max_bubble_power": stats_def.max_bubble_power,
		"initial_move_speed": stats_def.initial_move_speed,
		"max_move_speed": stats_def.max_move_speed,
		"stats_id": stats_def.stats_id,
		"presentation_id": presentation_def.presentation_id,
		"default_bubble_style_id": character_def.default_bubble_style_id,
		"selection_portrait_path": character_def.selection_portrait_path,
	}


static func _ensure_loaded() -> void:
	if _character_registry.is_empty():
		load_all()


static func _scan_stats_registry() -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(STATS_DIR):
		return result
	for file_name in DirAccess.get_files_at(STATS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [STATS_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is CharacterStatsDefScript:
			continue
		var def := resource as CharacterStatsDef
		if def.stats_id.is_empty():
			continue
		result[def.stats_id] = resource_path
	return result


static func _scan_presentation_registry() -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(PRESENTATION_DIR):
		return result
	for file_name in DirAccess.get_files_at(PRESENTATION_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [PRESENTATION_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is CharacterPresentationDefScript:
			continue
		var def := resource as CharacterPresentationDef
		if def.presentation_id.is_empty():
			continue
		result[def.presentation_id] = resource_path
	return result


static func _load_character_def(entry: Dictionary) -> CharacterDef:
	var resource_path := String(entry.get("def_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterDefScript:
		return null
	return resource


static func _load_character_stats(entry: Dictionary) -> CharacterStatsDef:
	var resource_path := String(entry.get("stats_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterStatsDefScript:
		return null
	return resource


static func _load_character_presentation(entry: Dictionary) -> CharacterPresentationDef:
	var resource_path := String(entry.get("presentation_resource_path", ""))
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource == null or not resource is CharacterPresentationDefScript:
		return null
	return resource


static func _resolve_content_hash(character_id: String, primary_hash: String, secondary_hash: String, tertiary_hash: String) -> String:
	if not primary_hash.is_empty():
		return primary_hash
	if not secondary_hash.is_empty():
		return secondary_hash
	if not tertiary_hash.is_empty():
		return tertiary_hash
	return "character_%s_fallback_v1" % character_id
