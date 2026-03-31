class_name MapCatalog
extends RefCounted

const _MAP_ENTRIES := {
	"default_map": {
		"resource_path": "res://content/maps/resources/map_small_square.tres",
		"metadata": {
			"map_id": "default_map",
			"display_name": "Default Plaza",
			"version": 1,
			"width": 13,
			"height": 11,
			"content_hash": "map_small_square_v1",
			"spawn_points": [Vector2i(1, 1), Vector2i(11, 1), Vector2i(1, 9), Vector2i(11, 9)],
			"item_spawn_profile_id": "default_items",
		}
	},
	"large_map": {
		"resource_path": "res://content/maps/resources/map_cross_arena.tres",
		"metadata": {
			"map_id": "large_map",
			"display_name": "Cross Arena",
			"version": 1,
			"width": 13,
			"height": 11,
			"content_hash": "map_cross_arena_v1",
			"spawn_points": [Vector2i(1, 1), Vector2i(11, 1), Vector2i(1, 9), Vector2i(11, 9)],
			"item_spawn_profile_id": "default_items",
		}
	},
}


static func get_map_ids() -> Array[String]:
	var map_ids: Array[String] = []
	for map_id in _MAP_ENTRIES.keys():
		map_ids.append(String(map_id))
	map_ids.sort()
	return map_ids


static func get_map_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for map_id in get_map_ids():
		var metadata := get_map_metadata(map_id)
		if metadata.is_empty():
			continue
		entries.append(metadata)
	return entries


static func get_default_map_id() -> String:
	var map_ids := get_map_ids()
	if map_ids.is_empty():
		return ""
	return map_ids[0]


static func has_map(map_id: String) -> bool:
	return _MAP_ENTRIES.has(map_id)


static func get_map_path(map_id: String) -> String:
	if not has_map(map_id):
		return ""
	return String(_MAP_ENTRIES[map_id].get("resource_path", ""))


static func get_map_metadata(map_id: String) -> Dictionary:
	if not has_map(map_id):
		return {}
	return _MAP_ENTRIES[map_id].get("metadata", {}).duplicate(true)
