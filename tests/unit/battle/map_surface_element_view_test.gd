extends "res://tests/gut/base/qqt_unit_test.gd"

const MapSurfaceElementViewScript = preload("res://presentation/battle/scene/map_surface_element_view.gd")


func test_main() -> void:
	var ok := true
	ok = _test_source_scale_preserves_native_surface_overlap() and ok
	ok = _test_default_edge_bleed_is_metadata_only_for_source_scale() and ok
	ok = _test_die_texture_reanchors_without_fade() and ok
	ok = _test_center_anchor_aligns_to_ground_center() and ok


func _test_source_scale_preserves_native_surface_overlap() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	var texture := _make_texture(43, 56)
	view.configure({
		"cell": Vector2i(2, 3),
		"footprint": Vector2i.ONE,
		"anchor_mode": "bottom_right",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
		"edge_bleed_px": 0.0,
	}, 40.0, texture)
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check((dump.get("scale", Vector2.ONE) as Vector2) == Vector2.ONE, "surface should preserve source pixels in 40px mode", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx((dump.get("position", Vector2.ZERO) as Vector2).x, 77.0), "bottom-right source scale should keep native overlap against 40px cells", "map_surface_element_view") and ok
	view.free()
	return ok


func _test_default_edge_bleed_is_metadata_only_for_source_scale() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	var texture := _make_texture(40, 40)
	view.configure({
		"cell": Vector2i(0, 0),
		"footprint": Vector2i.ONE,
		"anchor_mode": "bottom_right",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
	}, 40.0, texture)
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check((dump.get("scale", Vector2.ONE) as Vector2) == Vector2.ONE, "surface should not rescale formal 40px assets", "map_surface_element_view") and ok
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
	}, 40.0, stand_texture, die_texture)
	view.play_die_and_dispose()
	var dump: Dictionary = view.debug_dump_layout()
	var ok := true
	ok = qqt_check((dump.get("texture_size", Vector2.ZERO) as Vector2) == Vector2(66, 73), "die should swap to die texture immediately", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx(view.modulate.a, 1.0), "die should not use alpha fade", "map_surface_element_view") and ok
	view.queue_free()
	return ok


func _test_center_anchor_aligns_to_ground_center() -> bool:
	var view: Node2D = MapSurfaceElementViewScript.new()
	var texture := _make_texture(40, 40)
	view.configure({
		"cell": Vector2i(2, 3),
		"footprint": Vector2i.ONE,
		"anchor_mode": "center",
		"offset_px": Vector2.ZERO,
		"render_role": "surface",
	}, 40.0, texture)
	var dump: Dictionary = view.debug_dump_layout()
	var pos := dump.get("position", Vector2.ZERO) as Vector2
	var ok := true
	ok = qqt_check(is_equal_approx(pos.x, 80.0), "center anchor x should align sprite center to ground center", "map_surface_element_view") and ok
	ok = qqt_check(is_equal_approx(pos.y, 120.0), "center anchor y should align sprite center to ground center", "map_surface_element_view") and ok
	view.free()
	return ok


func _make_texture(width: int, height: int) -> Texture2D:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)
