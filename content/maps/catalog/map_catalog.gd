class_name MapCatalog
extends RefCounted

const MAP_REGISTRY := {
	"default_map": {
		"display_name": "Default Plaza",
		"resource_path": "res://content/maps/resources/map_small_square.tres",
		"is_default": true,
		"is_formal": true,
	},
	"large_map": {
		"display_name": "Cross Arena",
		"resource_path": "res://content/maps/resources/map_cross_arena.tres",
		"is_formal": true,
	},
	"test_square": {
		"display_name": "测试方形图",
		"def_path": "res://gameplay/config/map_defs/square_map_def.gd",
		"is_formal": false,
		"debug_only": true,
	}
}


static func get_map_ids() -> Array[String]:
	var map_ids: Array[String] = []
	for map_id in MAP_REGISTRY.keys():
		map_ids.append(String(map_id))
	map_ids.sort()
	return map_ids


static func get_map_entries() -> Array:
	var entries: Array = []
	for map_id in get_map_ids():
		var entry: Dictionary = MAP_REGISTRY[map_id]
		if not bool(entry.get("is_formal", true)):
			continue
		var display_name := String(entry.get("display_name", map_id))
		if display_name.is_empty():
			continue
		var metadata := get_map_metadata(map_id)
		entries.append({
			"id": map_id,
			"display_name": display_name,
			"version": int(metadata.get("version", 1)),
			"content_hash": String(metadata.get("content_hash", "")),
			"width": int(metadata.get("width", 0)),
			"height": int(metadata.get("height", 0)),
			"item_spawn_profile_id": String(metadata.get("item_spawn_profile_id", "")),
			"resource_path": get_map_path(map_id),
		})
	return entries


static func get_default_map_id() -> String:
	for map_id in get_map_ids():
		if bool(MAP_REGISTRY[map_id].get("is_default", false)):
			return map_id
	var map_ids := get_map_ids()
	if map_ids.is_empty():
		return ""
	return map_ids[0]


static func has_map(map_id: String) -> bool:
	return MAP_REGISTRY.has(map_id)


static func get_map_def_path(map_id: String) -> String:
	if not MAP_REGISTRY.has(map_id):
		return ""
	return String(MAP_REGISTRY[map_id].get("def_path", ""))


static func get_map_path(map_id: String) -> String:
	if not MAP_REGISTRY.has(map_id):
		return ""
	var resource_path := String(MAP_REGISTRY[map_id].get("resource_path", ""))
	if not resource_path.is_empty():
		return resource_path
	return get_map_def_path(map_id)


static func get_map_metadata(map_id: String) -> Dictionary:
	if map_id.is_empty() or not has_map(map_id):
		return {}
	var entry: Dictionary = MAP_REGISTRY[map_id]
	var metadata: Dictionary = {}
	if String(entry.get("resource_path", "")).ends_with(".tres"):
		var map_resource := load(String(entry.get("resource_path", "")))
		if map_resource != null and map_resource is MapResource:
			metadata = (map_resource as MapResource).to_metadata()
	if metadata.is_empty():
		metadata = _load_map_def_config(map_id)
	if metadata.is_empty():
		return {}
	metadata["id"] = map_id
	metadata["display_name"] = String(entry.get("display_name", metadata.get("display_name", map_id)))
	metadata["resource_path"] = String(entry.get("resource_path", ""))
	metadata["def_path"] = String(entry.get("def_path", ""))
	metadata["is_formal"] = bool(entry.get("is_formal", true))
	metadata["debug_only"] = bool(entry.get("debug_only", false))
	return metadata


static func _load_map_def_config(map_id: String) -> Dictionary:
	if map_id.is_empty() or not has_map(map_id):
		return {}
	var def_path := get_map_def_path(map_id)
	if def_path.is_empty():
		return {}
	var script := load(def_path)
	if script == null or not script.has_method("build"):
		return {}
	var built_config = script.build()
	if built_config is Dictionary:
		return (built_config as Dictionary).duplicate(true)
	return {}
