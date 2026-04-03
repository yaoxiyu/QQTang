class_name CharacterSkinCatalog
extends RefCounted

const CharacterSkinDefScript = preload("res://content/character_skins/defs/character_skin_def.gd")
const DATA_DIR := "res://content/character_skins/data/skins"

static var _skins_by_id: Dictionary = {}
static var _ordered_ids: Array[String] = []


static func load_all() -> void:
	_skins_by_id.clear()
	_ordered_ids.clear()
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		push_error("CharacterSkinCatalog data dir missing: %s" % DATA_DIR)
		return

	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [DATA_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is CharacterSkinDefScript:
			push_error("CharacterSkinCatalog failed to load skin def: %s" % resource_path)
			continue
		var def := resource as CharacterSkinDef
		if def.skin_id.is_empty():
			push_error("CharacterSkinCatalog skin_id is empty: %s" % resource_path)
			continue
		_skins_by_id[def.skin_id] = def

	for skin_id in _skins_by_id.keys():
		_ordered_ids.append(String(skin_id))
	_ordered_ids.sort()


static func get_by_id(skin_id: String) -> CharacterSkinDef:
	if _skins_by_id.is_empty():
		load_all()
	if not _skins_by_id.has(skin_id):
		return null
	return _skins_by_id[skin_id] as CharacterSkinDef


static func get_all() -> Array[CharacterSkinDef]:
	if _skins_by_id.is_empty():
		load_all()
	var result: Array[CharacterSkinDef] = []
	for skin_id in _ordered_ids:
		result.append(_skins_by_id[skin_id] as CharacterSkinDef)
	return result


static func has_id(skin_id: String) -> bool:
	if _skins_by_id.is_empty():
		load_all()
	return _skins_by_id.has(skin_id)


static func get_default_skin_id() -> String:
	if _skins_by_id.is_empty():
		load_all()
	if _ordered_ids.is_empty():
		return ""
	return _ordered_ids[0]
