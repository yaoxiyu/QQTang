class_name AudioCatalog
extends RefCounted

const AudioAssetDefScript = preload("res://content/audio/defs/audio_asset_def.gd")

const DATA_DIR_BGM := "res://content/audio/data/bgm/"
const DATA_DIR_SFX := "res://content/audio/data/sfx/"

static var _assets_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []
static var _loaded := false

static func load_all() -> void:
	if _loaded:
		return
	_assets_by_id.clear()
	_ordered_ids.clear()
	_scan_directory(DATA_DIR_BGM)
	_scan_directory(DATA_DIR_SFX)
	_ordered_ids.sort()
	_loaded = true

static func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := dir_path + file_name
			var resource := load(full_path)
			if resource != null and resource is AudioAssetDefScript:
				var def := resource
				if not def.audio_id.is_empty():
					_assets_by_id[def.audio_id] = def
					_ordered_ids.append(def.audio_id)
		file_name = dir.get_next()
	dir.list_dir_end()

static func get_by_id(audio_id: String) -> Resource:
	load_all()
	return _assets_by_id.get(audio_id, null)

static func has_id(audio_id: String) -> bool:
	load_all()
	return _assets_by_id.has(audio_id)

static func get_all_ids() -> Array[String]:
	load_all()
	return _ordered_ids.duplicate()

static func get_all_defs() -> Array:
	load_all()
	var result: Array = []
	for audio_id in _ordered_ids:
		var def: Resource = _assets_by_id[audio_id]
		result.append(def)
	return result

static func get_by_category(category: String) -> Array:
	load_all()
	var result: Array = []
	for audio_id in _ordered_ids:
		var def: Resource = _assets_by_id[audio_id]
		if def.category == category:
			result.append(def)
	return result

static func resolve_alias(audio_id: String) -> Resource:
	var def := get_by_id(audio_id)
	if def == null:
		return null
	if not def.alias_of.is_empty():
		return get_by_id(def.alias_of)
	return def

static func reload() -> void:
	_loaded = false
	_assets_by_id.clear()
	_ordered_ids.clear()
	load_all()
