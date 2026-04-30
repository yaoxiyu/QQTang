class_name BubbleCatalog
extends RefCounted

const BubbleStyleDefScript = preload("res://content/bubbles/defs/bubble_style_def.gd")
const BubbleGameplayDefScript = preload("res://content/bubbles/defs/bubble_gameplay_def.gd")
const GeneratedCatalogIndexLoaderScript = preload("res://content/catalog_index/generated_catalog_index_loader.gd")

const STYLE_DIR := "res://content/bubbles/data/style"
const GAMEPLAY_DIR := "res://content/bubbles/data/gameplay"

const LEGACY_BUBBLE_REGISTRY := {}

static var _bubble_registry: Dictionary = {}
static var _ordered_bubble_ids: Array[String] = []


static func load_all() -> void:
	_bubble_registry.clear()
	_ordered_bubble_ids.clear()

	if GeneratedCatalogIndexLoaderScript.has_index("bubbles"):
		if _load_from_generated_index():
			return

	var gameplay_by_id := _scan_gameplay_registry()

	if DirAccess.dir_exists_absolute(STYLE_DIR):
		for file_name in DirAccess.get_files_at(STYLE_DIR):
			if not file_name.ends_with(".tres"):
				continue
			var resource_path := "%s/%s" % [STYLE_DIR, file_name]
			var resource := load(resource_path)
			if resource == null or not resource is BubbleStyleDefScript:
				push_error("BubbleCatalog failed to load BubbleStyleDef: %s" % resource_path)
				continue
			var def := resource as BubbleStyleDef
			var bubble_id := String(def.bubble_style_id)
			if bubble_id.is_empty():
				push_error("BubbleCatalog bubble_style_id is empty: %s" % resource_path)
				continue
			_bubble_registry[bubble_id] = {
				"display_name": String(def.display_name if not def.display_name.is_empty() else bubble_id),
				"style_resource_path": resource_path,
				"gameplay_resource_path": String(gameplay_by_id.get(_resolve_gameplay_id_for_style(bubble_id), "")),
				"type": int(def.bubble_type),
				"power": int(def.power),
				"footprint_cells": int(def.footprint_cells),
				"player_obtainable": bool(def.player_obtainable),
			}

	if _bubble_registry.is_empty():
		for bubble_id in LEGACY_BUBBLE_REGISTRY.keys():
			_bubble_registry[String(bubble_id)] = LEGACY_BUBBLE_REGISTRY[bubble_id].duplicate(true)

	for bubble_id in _bubble_registry.keys():
		_ordered_bubble_ids.append(String(bubble_id))
	_ordered_bubble_ids.sort()


static func _load_from_generated_index() -> bool:
	var entries := GeneratedCatalogIndexLoaderScript.load_entries("bubbles")
	if entries.is_empty():
		return false
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var bubble_id := String(entry.get("id", ""))
		if bubble_id.is_empty():
			continue
		_bubble_registry[bubble_id] = {
			"display_name": String(entry.get("display_name", bubble_id)),
			"style_resource_path": String(entry.get("style_resource_path", "")),
			"gameplay_resource_path": String(entry.get("gameplay_resource_path", "")),
			"type": int(entry.get("type", 1)),
			"power": int(entry.get("power", 1)),
			"footprint_cells": int(entry.get("footprint_cells", 1)),
			"player_obtainable": bool(entry.get("player_obtainable", true)),
		}
	_ordered_bubble_ids.clear()
	for bubble_id in _bubble_registry.keys():
		_ordered_bubble_ids.append(String(bubble_id))
	_ordered_bubble_ids.sort()
	return not _bubble_registry.is_empty()


static func get_bubble_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_bubble_ids.duplicate()


static func get_default_bubble_id() -> String:
	_ensure_loaded()
	if _ordered_bubble_ids.is_empty():
		return ""
	return _ordered_bubble_ids[0]


static func has_bubble(bubble_id: String) -> bool:
	_ensure_loaded()
	return _bubble_registry.has(bubble_id)


static func get_bubble_entries() -> Array[Dictionary]:
	_ensure_loaded()
	var entries: Array[Dictionary] = []
	for bubble_id in _ordered_bubble_ids:
		if not has_bubble(bubble_id):
			continue
		var entry: Dictionary = _bubble_registry[bubble_id]
		entries.append({
			"id": bubble_id,
			"display_name": String(entry.get("display_name", bubble_id)),
			"style_resource_path": String(entry.get("style_resource_path", "")),
			"gameplay_resource_path": String(entry.get("gameplay_resource_path", "")),
			"type": int(entry.get("type", 1)),
			"power": int(entry.get("power", 1)),
			"footprint_cells": int(entry.get("footprint_cells", 1)),
			"player_obtainable": bool(entry.get("player_obtainable", true)),
			"is_default": bubble_id == get_default_bubble_id(),
		})
	return entries


static func get_style_resource_path(bubble_id: String) -> String:
	_ensure_loaded()
	if not has_bubble(bubble_id):
		return ""
	return String(_bubble_registry[bubble_id].get("style_resource_path", ""))


static func get_gameplay_resource_path(bubble_id: String) -> String:
	_ensure_loaded()
	if not has_bubble(bubble_id):
		return ""
	return String(_bubble_registry[bubble_id].get("gameplay_resource_path", ""))


static func _ensure_loaded() -> void:
	if _bubble_registry.is_empty():
		load_all()


static func _scan_gameplay_registry() -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(GAMEPLAY_DIR):
		return result
	for file_name in DirAccess.get_files_at(GAMEPLAY_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [GAMEPLAY_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is BubbleGameplayDefScript:
			continue
		var def := resource as BubbleGameplayDef
		if def.bubble_gameplay_id.is_empty():
			continue
		result[def.bubble_gameplay_id] = resource_path
	return result


static func _resolve_gameplay_id_for_style(bubble_id: String) -> String:
	var suffix := bubble_id
	if bubble_id.begins_with("bubble_"):
		suffix = bubble_id.trim_prefix("bubble_")
	var candidate_id := "bubble_gameplay_%s" % suffix
	return candidate_id
