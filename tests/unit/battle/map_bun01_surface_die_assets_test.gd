extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleMapViewControllerScript = preload("res://presentation/battle/scene/map_view_controller.gd")


func test_main() -> void:
	var ok := true
	ok = _test_bun01_die_frames_are_resolvable() and ok
	ok = _test_bun01_die_spriteframes_cache_builds() and ok


func _test_bun01_die_frames_are_resolvable() -> bool:
	var map_view := BattleMapViewControllerScript.new()
	var frames := map_view._resolve_animation_frames("res://external/assets/maps/elements/bun/elem7_die.gif")
	var ok := true
	ok = qqt_check(frames.size() > 0, "bun01 die gif should resolve png frame sequence", "map_bun01_surface_die_assets") and ok
	map_view.free()
	return ok


func _test_bun01_die_spriteframes_cache_builds() -> bool:
	var map_view := BattleMapViewControllerScript.new()
	var path := "res://external/assets/maps/elements/bun/elem7_die.gif"
	var frames := map_view._resolve_animation_frames(path)
	var sprite_frames := map_view._resolve_sprite_frames_cached(path, frames, 12.0, false)
	var ok := true
	ok = qqt_check(sprite_frames != null, "die sprite frames cache should build", "map_bun01_surface_die_assets") and ok
	if sprite_frames != null:
		ok = qqt_check(sprite_frames.get_frame_count("active") == frames.size(), "sprite frame cache count should match source frames", "map_bun01_surface_die_assets") and ok
	map_view.free()
	return ok
