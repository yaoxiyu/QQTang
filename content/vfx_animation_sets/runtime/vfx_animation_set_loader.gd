class_name VfxAnimationSetLoader
extends RefCounted

const VfxAnimationSetCatalogScript = preload("res://content/vfx_animation_sets/catalog/vfx_animation_set_catalog.gd")


static func load_vfx_set(vfx_set_id: String) -> Resource:
	if vfx_set_id.is_empty():
		return null
	var vfx_set := VfxAnimationSetCatalogScript.get_by_id(vfx_set_id)
	if vfx_set == null:
		push_error("VfxAnimationSetLoader.load_vfx_set failed: missing VfxAnimationSetDef for %s" % vfx_set_id)
	return vfx_set

