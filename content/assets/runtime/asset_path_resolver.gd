class_name AssetPathResolver
extends RefCounted

const LOCAL_CONFIG_PATH := "res://config/local_asset_roots.json"
const EXAMPLE_CONFIG_PATH := "res://config/local_asset_roots.example.json"
const ENV_ASSET_ROOT := "QQT_ASSET_ROOT"
const ASSET_SCHEME := "asset://"
const DEFAULT_ASSET_PACK_ID := "qqt-assets"

static var _config_loaded := false
static var _asset_roots: Array[Dictionary] = []
static var _fallback_to_project_assets := true
static var _last_error: Dictionary = {}


static func resolve_path(path: String) -> String:
	if path.begins_with(ASSET_SCHEME):
		return resolve_asset_uri(path)
	return path


static func resolve_asset_uri(uri: String) -> String:
	var parts := _parse_asset_uri(uri)
	if parts.is_empty():
		_set_error("", uri, "", [], "Use asset://<pack>/<path>.")
		return ""
	var pack_id := String(parts.get("pack_id", ""))
	var logical_path := String(parts.get("logical_path", ""))
	var searched_roots: Array[String] = []

	_ensure_config_loaded()
	for root_entry in _asset_roots:
		if not bool(root_entry.get("enabled", true)):
			continue
		if String(root_entry.get("asset_pack_id", "")) != pack_id:
			continue
		var root := String(root_entry.get("root", "")).strip_edges()
		if root.is_empty():
			continue
		var candidate := _join_local_path(root, logical_path)
		searched_roots.append(root)
		if FileAccess.file_exists(candidate):
			return candidate

	var env_root := OS.get_environment(ENV_ASSET_ROOT).strip_edges()
	if not env_root.is_empty():
		var env_candidate := _join_local_path(env_root, logical_path)
		searched_roots.append(env_root)
		if FileAccess.file_exists(env_candidate):
			return env_candidate

	if _fallback_to_project_assets:
		var fallback_path := _to_project_fallback(logical_path)
		searched_roots.append("project fallback")
		if not fallback_path.is_empty() and FileAccess.file_exists(fallback_path):
			return fallback_path

	_set_error(
		pack_id,
		logical_path,
		_get_expected_version(pack_id),
		searched_roots,
		"scripts/assets/validate_asset_pack.ps1 -AssetPackRoot <asset-pack-root>"
	)
	return ""


static func file_exists(path: String) -> bool:
	var resolved := resolve_path(path)
	return not resolved.is_empty() and FileAccess.file_exists(resolved)


static func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)


static func get_last_error_text() -> String:
	if _last_error.is_empty():
		return ""
	return "Missing asset:\n  pack: %s\n  path: %s\n  expected version: %s\n  searched:\n    %s\n  fix:\n    %s" % [
		String(_last_error.get("asset_pack_id", "")),
		String(_last_error.get("logical_path", "")),
		String(_last_error.get("expected_version", "")),
		"\n    ".join(PackedStringArray(_last_error.get("searched_roots", []))),
		String(_last_error.get("suggested_command", ""))
	]


static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	_asset_roots.clear()
	_fallback_to_project_assets = true
	var config_path := LOCAL_CONFIG_PATH if FileAccess.file_exists(LOCAL_CONFIG_PATH) else EXAMPLE_CONFIG_PATH
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("AssetPathResolver failed to open config: %s" % config_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("AssetPathResolver invalid config json: %s" % config_path)
		return
	var config := parsed as Dictionary
	_fallback_to_project_assets = bool(config.get("fallback_to_project_assets", true))
	var roots = config.get("asset_roots", [])
	if not roots is Array:
		return
	for root in roots:
		if root is Dictionary:
			_asset_roots.append(root as Dictionary)


static func _parse_asset_uri(uri: String) -> Dictionary:
	if not uri.begins_with(ASSET_SCHEME):
		return {}
	var remainder := uri.substr(ASSET_SCHEME.length())
	var separator := remainder.find("/")
	if separator <= 0 or separator >= remainder.length() - 1:
		return {}
	return {
		"pack_id": remainder.substr(0, separator),
		"logical_path": remainder.substr(separator + 1)
	}


static func _join_local_path(root: String, logical_path: String) -> String:
	var normalized_root := root.replace("\\", "/").trim_suffix("/")
	if not normalized_root.is_absolute_path():
		normalized_root = ProjectSettings.globalize_path("res://%s" % normalized_root)
	var normalized_path := logical_path.replace("\\", "/").trim_prefix("/")
	return "%s/%s" % [normalized_root, normalized_path]


static func _to_project_fallback(logical_path: String) -> String:
	var normalized := logical_path.replace("\\", "/")
	if normalized.begins_with("derived/"):
		return "res://%s" % normalized.substr("derived/".length())
	if normalized.begins_with("source/"):
		return "res://%s" % normalized.substr("source/".length())
	return ""


static func _get_expected_version(pack_id: String) -> String:
	_ensure_config_loaded()
	for root_entry in _asset_roots:
		if String(root_entry.get("asset_pack_id", "")) != pack_id:
			continue
		var root := String(root_entry.get("root", "")).strip_edges()
		if root.is_empty():
			continue
		var asset_pack_path := _join_local_path(root, "asset_pack.json")
		if not FileAccess.file_exists(asset_pack_path):
			continue
		var file := FileAccess.open(asset_pack_path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			return String((parsed as Dictionary).get("version", ""))
	return ""


static func _set_error(pack_id: String, logical_path: String, expected_version: String, searched_roots: Array[String], suggested_command: String) -> void:
	_last_error = {
		"asset_pack_id": pack_id,
		"logical_path": logical_path,
		"expected_version": expected_version,
		"searched_roots": searched_roots,
		"suggested_command": suggested_command
	}
	push_error(get_last_error_text())
