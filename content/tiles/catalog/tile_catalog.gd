class_name TileCatalog
extends RefCounted

const TILE_REGISTRY := {
	"tile_floor": {
		"display_name": "地板",
		"resource_path": "res://content/tiles/data/tile/tile_floor.tres",
		"is_default": true,
	},
	"tile_solid_wall": {
		"display_name": "实心墙",
		"resource_path": "res://content/tiles/data/tile/tile_solid_wall.tres",
	},
	"tile_breakable_brick": {
		"display_name": "可破坏砖块",
		"resource_path": "res://content/tiles/data/tile/tile_breakable_brick.tres",
	},
}


static func get_tile_ids() -> Array[String]:
	var tile_ids: Array[String] = []
	for tile_id in TILE_REGISTRY.keys():
		tile_ids.append(String(tile_id))
	tile_ids.sort()
	return tile_ids


static func get_default_tile_id() -> String:
	for tile_id in get_tile_ids():
		if bool(TILE_REGISTRY[tile_id].get("is_default", false)):
			return tile_id
	var tile_ids := get_tile_ids()
	if tile_ids.is_empty():
		return ""
	return tile_ids[0]


static func has_tile(tile_id: String) -> bool:
	return TILE_REGISTRY.has(tile_id)


static func get_tile_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for tile_id in get_tile_ids():
		if not has_tile(tile_id):
			continue
		var entry: Dictionary = TILE_REGISTRY[tile_id]
		entries.append({
			"id": tile_id,
			"display_name": String(entry.get("display_name", tile_id)),
			"resource_path": String(entry.get("resource_path", "")),
			"is_default": bool(entry.get("is_default", false)),
		})
	return entries


static func get_tile_resource_path(tile_id: String) -> String:
	if not has_tile(tile_id):
		return ""
	return String(TILE_REGISTRY[tile_id].get("resource_path", ""))
