class_name BubbleLoader
extends RefCounted

const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleStyleDefScript = preload("res://content/bubbles/defs/bubble_style_def.gd")
const BubbleGameplayDefScript = preload("res://content/bubbles/defs/bubble_gameplay_def.gd")


static func load_style(bubble_id: String) -> BubbleStyleDef:
	var resolved_bubble_id := bubble_id if BubbleCatalogScript.has_bubble(bubble_id) else BubbleCatalogScript.get_default_bubble_id()
	var resource_path := BubbleCatalogScript.get_style_resource_path(resolved_bubble_id)
	if resource_path.is_empty():
		push_error("BubbleLoader.load_style failed: missing style resource path for bubble_id=%s" % resolved_bubble_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is BubbleStyleDefScript:
		push_error("BubbleLoader.load_style failed: invalid style resource path=%s" % resource_path)
		return null
	return resource


static func load_gameplay(bubble_id: String) -> BubbleGameplayDef:
	var resolved_bubble_id := bubble_id if BubbleCatalogScript.has_bubble(bubble_id) else BubbleCatalogScript.get_default_bubble_id()
	var resource_path := BubbleCatalogScript.get_gameplay_resource_path(resolved_bubble_id)
	if resource_path.is_empty():
		push_error("BubbleLoader.load_gameplay failed: missing gameplay resource path for bubble_id=%s" % resolved_bubble_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is BubbleGameplayDefScript:
		push_error("BubbleLoader.load_gameplay failed: invalid gameplay resource path=%s" % resource_path)
		return null
	return resource


static func load_metadata(bubble_id: String) -> Dictionary:
	var style := load_style(bubble_id)
	var gameplay := load_gameplay(bubble_id)
	if style == null or gameplay == null:
		return {}
	return {
		"bubble_style_id": style.bubble_style_id,
		"display_name": style.display_name,
		"bubble_scene_path": style.bubble_scene_path,
		"icon_path": style.icon_path,
		"spawn_fx_id": style.spawn_fx_id,
		"explode_fx_id": style.explode_fx_id,
		"bubble_gameplay_id": gameplay.bubble_gameplay_id,
		"fuse_ticks": gameplay.fuse_ticks,
		"move_speed_level": gameplay.move_speed_level,
		"can_be_kicked": gameplay.can_be_kicked,
		"content_hash": String(style.content_hash if not style.content_hash.is_empty() else gameplay.content_hash),
	}


static func build_loadout(bubble_id: String) -> Dictionary:
	var metadata := load_metadata(bubble_id)
	if metadata.is_empty():
		return {
			"bubble_style_id": "",
		}
	return metadata.duplicate(true)
