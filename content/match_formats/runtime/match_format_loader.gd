class_name MatchFormatLoader
extends RefCounted

const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const MatchFormatDefScript = preload("res://content/match_formats/defs/match_format_def.gd")


static func load_match_format_def(match_format_id: String) -> MatchFormatDef:
	var resolved_match_format_id := match_format_id if MatchFormatCatalogScript.has_match_format(match_format_id) else MatchFormatCatalogScript.get_default_match_format_id()
	var resource_path := MatchFormatCatalogScript.get_match_format_resource_path(resolved_match_format_id)
	if resource_path.is_empty():
		push_error("MatchFormatLoader.load_match_format_def failed: missing resource path for match_format_id=%s" % resolved_match_format_id)
		return null
	var resource := load(resource_path)
	if resource == null or not resource is MatchFormatDefScript:
		push_error("MatchFormatLoader.load_match_format_def failed: invalid resource path=%s" % resource_path)
		return null
	return resource


static func load_metadata(match_format_id: String) -> Dictionary:
	var match_format_def := load_match_format_def(match_format_id)
	if match_format_def == null:
		return {}
	return {
		"match_format_id": match_format_def.match_format_id,
		"display_name": match_format_def.display_name,
		"team_count": match_format_def.team_count,
		"required_party_size": match_format_def.required_party_size,
		"expected_total_player_count": match_format_def.expected_total_player_count,
		"map_pool_resolution_policy": match_format_def.map_pool_resolution_policy,
		"enabled_in_match_room": match_format_def.enabled_in_match_room,
		"sort_order": match_format_def.sort_order,
		"content_hash": match_format_def.content_hash,
	}
