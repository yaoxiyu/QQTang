class_name TeamColorPaletteLoader
extends RefCounted

const TeamColorPaletteCatalogScript = preload("res://content/team_colors/catalog/team_color_palette_catalog.gd")


static func load_palette(palette_id: String) -> Resource:
	if palette_id.is_empty():
		return null
	var palette := TeamColorPaletteCatalogScript.get_by_id(palette_id)
	if palette == null:
		push_error("TeamColorPaletteLoader.load_palette failed: missing TeamColorPaletteDef for %s" % palette_id)
	return palette
