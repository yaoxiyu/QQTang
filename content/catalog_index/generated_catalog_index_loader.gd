class_name GeneratedCatalogIndexLoader
extends RefCounted

const BASE_DIR := "res://build/generated/content_catalog"

static var enabled := true


static func set_enabled(value: bool) -> void:
	enabled = value


static func index_path(content_kind: String) -> String:
	return "%s/%s_catalog_index.json" % [BASE_DIR, String(content_kind)]


static func has_index(content_kind: String) -> bool:
	if not enabled:
		return false
	return FileAccess.file_exists(index_path(content_kind))


static func load_index(content_kind: String) -> Dictionary:
	var path := index_path(content_kind)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GeneratedCatalogIndexLoader failed to open: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("GeneratedCatalogIndexLoader invalid json: %s" % path)
		return {}
	return parsed as Dictionary


static func load_entries(content_kind: String) -> Array:
	var payload := load_index(content_kind)
	if payload.is_empty():
		return []
	var entries = payload.get("entries", [])
	return entries if entries is Array else []
