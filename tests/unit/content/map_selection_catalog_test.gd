extends "res://tests/gut/base/qqt_unit_test.gd"

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")



func test_main() -> void:
	call_deferred("_main_body")


func _main_body() -> void:
	MapCatalogScript.load_all()
	var prefix := "map_selection_catalog_test"
	var ok := true
	ok = qqt_check(_has_queue_map("1v1", "casual", "desert", "map_desert01", 4), "desert map should support 1v1 casual variant", prefix) and ok
	ok = qqt_check(_has_queue_map("2v2", "casual", "desert", "map_desert01", 4), "desert map should support 2v2 casual variant", prefix) and ok
	ok = qqt_check(_has_queue_map("1v1", "casual", "match", "map_match01", 2), "match map should support 1v1 casual variant", prefix) and ok
	ok = qqt_check(not _format_enabled("4v4"), "4v4 should stay locked until a map has at least 8 spawn points", prefix) and ok
	var custom_binding := MapSelectionCatalogScript.get_map_binding("map_desert01")
	ok = qqt_check(int(custom_binding.get("max_player_count", 0)) == 4, "custom room binding should keep desert map capacity", prefix) and ok


func _format_enabled(match_format_id: String) -> bool:
	for entry in MapSelectionCatalogScript.get_matchmaking_format_entries():
		if String(entry.get("match_format_id", "")) == match_format_id:
			return bool(entry.get("enabled", false))
	return false


func _has_queue_map(match_format_id: String, queue_type: String, mode_id: String, map_id: String, max_player_count: int) -> bool:
	for entry in MapSelectionCatalogScript.get_matchmaking_maps(match_format_id, queue_type, mode_id):
		if String(entry.get("map_id", "")) == map_id and int(entry.get("max_player_count", 0)) == max_player_count:
			return true
	return false

