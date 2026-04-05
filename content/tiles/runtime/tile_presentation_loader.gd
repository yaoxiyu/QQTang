class_name TilePresentationLoader
extends RefCounted

const TilePresentationCatalogScript = preload("res://content/tiles/catalog/tile_presentation_catalog.gd")


static func load_tile_presentation(presentation_id: String) -> TilePresentationDef:
	if presentation_id.is_empty():
		push_error("TilePresentationLoader.load_tile_presentation failed: presentation_id is empty")
		return null
	var presentation := TilePresentationCatalogScript.get_by_id(presentation_id)
	if presentation == null:
		push_error("TilePresentationLoader.load_tile_presentation failed: missing TilePresentationDef for presentation_id=%s" % presentation_id)
		return null
	return presentation
