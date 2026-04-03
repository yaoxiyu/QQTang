class_name TileLoader
extends RefCounted

const TileCatalogScript = preload("res://content/tiles/catalog/tile_catalog.gd")
const TileDefScript = preload("res://content/tiles/defs/tile_def.gd")


static func load_tile_def(tile_id: String) -> TileDef:
	var resolved_tile_id := tile_id if TileCatalogScript.has_tile(tile_id) else TileCatalogScript.get_default_tile_id()
	var resource_path := TileCatalogScript.get_tile_resource_path(resolved_tile_id)
	if resource_path.is_empty():
		push_error("TileLoader.load_tile_def failed: missing resource path for tile_id=%s" % resolved_tile_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is TileDefScript:
		push_error("TileLoader.load_tile_def failed: invalid resource path=%s" % resource_path)
		return null
	return resource


static func load_metadata(tile_id: String) -> Dictionary:
	var tile_def := load_tile_def(tile_id)
	if tile_def == null:
		return {}
	return {
		"tile_id": tile_def.tile_id,
		"display_name": tile_def.display_name,
		"tile_type": tile_def.tile_type,
		"scene_path": tile_def.scene_path,
		"is_walkable": tile_def.is_walkable,
		"is_breakable": tile_def.is_breakable,
		"blocks_blast": tile_def.blocks_blast,
		"blocks_movement": tile_def.blocks_movement,
		"break_fx_id": tile_def.break_fx_id,
		"content_hash": tile_def.content_hash,
	}
