extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleDepthScript = preload("res://presentation/battle/battle_depth.gd")


func test_main() -> void:
	_test_airborne_item_depth_above_regular_row()
	_test_airplane_depth_is_above_airborne_item()
	_test_airplane_depth_stays_above_world_bottom()
	_test_airborne_world_api_matches_cell_api()
	_test_depth_domain_validation_passes_default_bounds()
	_test_debug_depth_band()


func _test_airborne_item_depth_above_regular_row() -> void:
	var from_cell := Vector2i(1, 3)
	var to_cell := Vector2i(4, 6)
	var airborne_z := BattleDepthScript.item_airborne_z(from_cell, to_cell)
	var regular_surface_z := BattleDepthScript.surface_z(Vector2i(4, 6))
	assert_true(airborne_z > regular_surface_z, "airborne item should stay above regular surface band on the same max row")


func _test_airplane_depth_is_above_airborne_item() -> void:
	var from_cell := Vector2i(2, 4)
	var to_cell := Vector2i(5, 7)
	var max_row := maxi(from_cell.y, to_cell.y)
	var plane_z := BattleDepthScript.airplane_z(max_row, 13)
	var airborne_z := BattleDepthScript.item_airborne_z(from_cell, to_cell)
	assert_true(plane_z > airborne_z, "airplane should stay above airborne item in sky domain")


func _test_airplane_depth_stays_above_world_bottom() -> void:
	var map_height := 13
	var airplane_z := BattleDepthScript.airplane_z(2, map_height)
	var bottom_regular := (map_height - 1) * BattleDepthScript.ROW_STEP + BattleDepthScript.LAYER_PRIORITY_SURFACE * BattleDepthScript.WITHIN_ROW_STEP
	assert_true(
		airplane_z >= bottom_regular + BattleDepthScript.AIRCRAFT_ABOVE_WORLD_MARGIN,
		"airplane z should stay above map bottom regular world band"
	)


func _test_airborne_world_api_matches_cell_api() -> void:
	var cell_size := 40.0
	var from_world := Vector2(0.25 * cell_size, 2.9 * cell_size)
	var to_world := Vector2(3.5 * cell_size, 6.1 * cell_size)
	var airborne_from_world := BattleDepthScript.item_airborne_z_from_world(from_world, to_world, cell_size)
	var from_cell := Vector2i(int(floor(from_world.x / cell_size)), int(floor(from_world.y / cell_size)))
	var to_cell := Vector2i(int(floor(to_world.x / cell_size)), int(floor(to_world.y / cell_size)))
	var airborne_from_cells := BattleDepthScript.item_airborne_z(from_cell, to_cell)
	assert_eq(airborne_from_world, airborne_from_cells, "world-based airborne api should be equivalent to cell-based api")


func _test_depth_domain_validation_passes_default_bounds() -> void:
	BattleDepthScript.reset_depth_domains()
	var validation := BattleDepthScript.validate_depth_domains(13)
	assert_true(bool(validation.get("ok", false)), "default depth domains should preserve safe ground/sky gap")
	assert_true(int(validation.get("gap", 0)) >= int(BattleDepthScript.SKY_GAP_MIN), "depth domain gap should satisfy minimum")


func _test_debug_depth_band() -> void:
	var z := BattleDepthScript.debug_z()
	assert_true(z > BattleDepthScript.airplane_z(0, 13), "debug z should stay above sky domain")
