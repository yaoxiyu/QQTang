extends ContentCsvGeneratorBase
class_name GenerateContentCatalogIndices

const GeneratedCatalogIndexLoaderScript = preload("res://content/catalog_index/generated_catalog_index_loader.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")

const OUTPUT_DIR := "res://build/generated/content_catalog"


func generate() -> void:
	_ensure_output_dir()
	var previous_enabled := GeneratedCatalogIndexLoaderScript.enabled
	GeneratedCatalogIndexLoaderScript.set_enabled(false)
	CharacterCatalogScript.load_all()
	BubbleCatalogScript.load_all()
	MapCatalogScript.load_all()
	ModeCatalogScript.load_all()
	RuleSetCatalogScript.load_all()
	MatchFormatCatalogScript.load_all()
	_write_index("characters", _character_entries())
	_write_index("bubbles", _bubble_entries())
	_write_index("maps", _map_entries())
	_write_index("modes", _mode_entries())
	_write_index("rulesets", _rule_entries())
	_write_index("match_formats", _match_format_entries())
	_write_summary()
	GeneratedCatalogIndexLoaderScript.set_enabled(previous_enabled)


func _write_index(kind: String, entries: Array) -> void:
	var payload := {
		"schema_version": 1,
		"content_kind": kind,
		"generated_at_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"entries": entries,
	}
	var path := "%s/%s_catalog_index.json" % [OUTPUT_DIR, kind]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("failed to write generated catalog index: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _character_entries() -> Array:
	var result: Array = []
	for entry in CharacterCatalogScript.get_character_entries():
		if not entry is Dictionary:
			continue
		var character_id := String(entry.get("id", ""))
		if character_id.is_empty():
			continue
		var catalog_entry := CharacterCatalogScript.get_character_entry(character_id)
		result.append({
			"id": character_id,
			"display_name": String(entry.get("display_name", character_id)),
			"def_resource_path": String(catalog_entry.get("def_resource_path", "")),
			"stats_resource_path": String(catalog_entry.get("stats_resource_path", "")),
			"presentation_resource_path": String(catalog_entry.get("presentation_resource_path", "")),
			"selection_order": int(entry.get("selection_order", 999999)),
			"type": int(entry.get("type", 0)),
			"content_hash": String(entry.get("content_hash", "")),
		})
	return result


func _bubble_entries() -> Array:
	var result: Array = []
	for entry in BubbleCatalogScript.get_bubble_entries():
		if not entry is Dictionary:
			continue
		var bubble_id := String(entry.get("id", ""))
		if bubble_id.is_empty():
			continue
		result.append({
			"id": bubble_id,
			"display_name": String(entry.get("display_name", bubble_id)),
			"style_resource_path": String(entry.get("style_resource_path", "")),
			"gameplay_resource_path": String(entry.get("gameplay_resource_path", "")),
			"type": int(entry.get("type", 1)),
			"power": int(entry.get("power", 1)),
			"footprint_cells": int(entry.get("footprint_cells", 1)),
			"player_obtainable": bool(entry.get("player_obtainable", true)),
		})
	return result


func _map_entries() -> Array:
	var result: Array = []
	for entry in MapCatalogScript.get_map_entries():
		if entry is Dictionary:
			var e := (entry as Dictionary).duplicate(true)
			e["id"] = String(e.get("id", e.get("map_id", "")))
			result.append(e)
	return result


func _mode_entries() -> Array:
	var result: Array = []
	for entry in ModeCatalogScript.get_mode_entries():
		if entry is Dictionary:
			var e := (entry as Dictionary).duplicate(true)
			e["id"] = String(e.get("mode_id", e.get("id", "")))
			result.append(e)
	return result


func _rule_entries() -> Array:
	var result: Array = []
	for entry in RuleSetCatalogScript.get_rule_entries():
		if entry is Dictionary:
			var e := (entry as Dictionary).duplicate(true)
			var rule_set_id := String(e.get("rule_set_id", e.get("id", "")))
			e["id"] = rule_set_id
			var def := RuleSetCatalogScript.get_by_id(rule_set_id)
			e["resource_path"] = String(def.resource_path) if def != null else ""
			result.append(e)
	return result


func _match_format_entries() -> Array:
	var result: Array = []
	for entry in MatchFormatCatalogScript.get_entries():
		if entry is Dictionary:
			var e := (entry as Dictionary).duplicate(true)
			e["id"] = String(e.get("match_format_id", e.get("id", "")))
			result.append(e)
	return result


func _write_summary() -> void:
	var summary := {
		"schema_version": 1,
		"generated_at_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"indices": ["characters", "bubbles", "maps", "modes", "rulesets", "match_formats"],
	}
	var path := "%s/content_catalog_summary.json" % OUTPUT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()


func _ensure_output_dir() -> void:
	var global_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
