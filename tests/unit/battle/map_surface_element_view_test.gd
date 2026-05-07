extends "res://tests/gut/base/qqt_unit_test.gd"

const MapSurfaceElementViewScript = preload("res://presentation/battle/scene/map_surface_element_view.gd")


func test_main() -> void:
	var ok := true
	ok = _test_cell_width_fit_closes_grid_gap() and ok
	ok = _test_default_cell_width_fit_adds_edge_bleed() and ok
	ok = _test_die_texture_reanchors_without_fade() and ok


func _test_cell_width_fit_closes_grid_gap() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	var texture := _make_texture(43, 56)
	view.configure({
		"cell": Vector2i(2, 3),
		"footprint": Vector2i.ONE,
		"anchor_mode": "bottom_right",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
		"edge_bleed_px": 0.0,
	}, 48.0, texture)
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check(is_equal_approx((dump.get("scale", Vector2.ONE) as Vector2).x, 48.0 / 43.0), "surface width should fit one cell", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx((dump.get("position", Vector2.ZERO) as Vector2).x, 96.0), "bottom-right fit should align left edge to cell after width normalization", "map_surface_element_view") and ok
	view.free()
	return ok


func _test_default_cell_width_fit_adds_edge_bleed() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	var texture := _make_texture(48, 48)
	view.configure({
		"cell": Vector2i(0, 0),
		"footprint": Vector2i.ONE,
		"anchor_mode": "bottom_right",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
	}, 48.0, texture)
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check(is_equal_approx((dump.get("scale", Vector2.ONE) as Vector2).x, 49.0 / 48.0), "surface should overdraw one pixel by default to cover camera sampling seams", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx(float(dump.get("edge_bleed_px", 0.0)), 1.0), "default edge bleed should be recorded", "map_surface_element_view") and ok
	view.free()
	return ok


func _test_die_texture_reanchors_without_fade() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	add_child(view)
	var stand_texture := _make_texture(43, 56)
	var die_texture := _make_texture(66, 73)
	view.configure({
		"cell": Vector2i(1, 1),
		"footprint": Vector2i.ONE,
		"anchor_mode": "bottom_right",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
		"die_duration_sec": 0.01,
	}, 48.0, stand_texture, die_texture)
	view.play_die_and_dispose()
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check((dump.get("texture_size", Vector2.ZERO) as Vector2) == Vector2(66, 73), "die should swap to die texture immediately", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx(view.modulate.a, 1.0), "die should not use alpha fade", "map_surface_element_view") and ok
	view.queue_free()
	return ok


func _make_texture(width: int, height: int) -> Texture2D:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)
