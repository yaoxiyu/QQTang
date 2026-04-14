extends Node

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	MapCatalogScript.load_all()
	var prefix := "map_selection_catalog_test"
	var ok := true
	ok = TestAssert.is_true(_has_ranked_map("1v1", "mode_classic", "map_classic_square", 2), "classic map should support 1v1 ranked variant", prefix) and ok
	ok = TestAssert.is_true(_has_ranked_map("2v2", "mode_classic", "map_classic_square", 4), "classic map should keep 2v2 ranked variant", prefix) and ok
	ok = TestAssert.is_true(not _format_enabled("4v4"), "4v4 should stay locked until a map has at least 8 spawn points", prefix) and ok
	var custom_binding := MapSelectionCatalogScript.get_map_binding("map_classic_square")
	ok = TestAssert.is_true(int(custom_binding.get("max_player_count", 0)) == 4, "custom room binding should keep legacy map capacity", prefix) and ok
	if ok:
		print("map_selection_catalog_test: PASS")
	test_finished.emit()


func _format_enabled(match_format_id: String) -> bool:
	for entry in MapSelectionCatalogScript.get_matchmaking_format_entries():
		if String(entry.get("match_format_id", "")) == match_format_id:
			return bool(entry.get("enabled", false))
	return false


func _has_ranked_map(match_format_id: String, mode_id: String, map_id: String, max_player_count: int) -> bool:
	for entry in MapSelectionCatalogScript.get_matchmaking_maps(match_format_id, "ranked", mode_id):
		if String(entry.get("map_id", "")) == map_id and int(entry.get("max_player_count", 0)) == max_player_count:
			return true
	return false
